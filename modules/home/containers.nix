{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# OCI CONTAINER RUNTIME SUBSTRATE (Home Manager / user-level)
#
# The per-user counterpart of the NixOS ft.containers module. Home Manager is
# inherently the calling user's scope, so this variant is always rootless — no
# service account, no rootful/rootless toggle. Podman runs natively per-user via
# a systemd --user socket; with the docker runtime the user's own rootless
# dockerd (managed outside Home Manager) is assumed to be present.
#
# Compose is always the genuine Docker Compose v2 binary, driven through the
# Docker-API-compatible user socket. Never podman-compose.
################################################################################

let
  cfg = config.ft.containers;

  # Docker-API-compatible user socket, using the systemd %t (XDG_RUNTIME_DIR)
  # specifier so it resolves per-session inside unit Environment lines.
  socketDefault = if cfg.runtime == "podman" then "%t/podman/podman.sock" else "%t/docker.sock";
in
{
  options.ft.containers = {
    enable = lib.mkEnableOption "user-level OCI container runtime" // {
      description = "Sets up a container runtime — Docker or Podman — that runs entirely under your own user account, no root needed. Comes with the real Docker Compose v2 and, optionally, Distrobox. Other user-level apps such as `ft.komodo` build on top of this and connect to it through `ft.containers.socket`.";
    };

    runtime = lib.mkOption {
      type = lib.types.enum [
        "docker"
        "podman"
      ];
      default = "podman";
      description = "Which container runtime to use. Podman runs natively as your own user through a systemd `--user` socket. Docker instead assumes you already have a rootless `dockerd` running for your user, set up outside Home Manager. Either way, the real `docker-compose` binary talks to it through a Docker-API-compatible socket.";
    };

    compose.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Installs the real Docker Compose v2 binary (`pkgs.docker-compose`) into your user profile. `podman-compose` is never used here.";
    };

    distrobox.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Installs Distrobox into your user profile, so you can run containers based on other Linux distributions that feel integrated with your host system.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/containers";
      description = "The base directory where your docker-compose projects and bind-mounted data live.";
    };

    socket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = socketDefault;
      description = "Read-only. The Docker-API-compatible socket (in systemd's `%t` form) that the runtime exposes. Other user-level apps built on this module, such as `ft.komodo`, use this value as their `DOCKER_HOST`.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optional (cfg.runtime == "podman") pkgs.podman
      ++ lib.optional (cfg.runtime == "docker") pkgs.docker-client
      ++ lib.optional cfg.compose.enable pkgs.docker-compose
      ++ lib.optional cfg.distrobox.enable pkgs.distrobox;

    home.sessionVariables.DOCKER_HOST = lib.mkDefault "unix://\${XDG_RUNTIME_DIR}/${
      if cfg.runtime == "podman" then "podman/podman.sock" else "docker.sock"
    }";

    # Podman runs daemonless, but a persistent user socket lets the docker-compose
    # binary and app services (ft.komodo) reach it via DOCKER_HOST.
    systemd.user.sockets.podman = lib.mkIf (cfg.runtime == "podman") {
      Unit.Description = "Podman API socket";
      Socket = {
        ListenStream = "%t/podman/podman.sock";
        SocketMode = lib.mkDefault "0660";
      };
      # List option left unwrapped so it merges rather than being replaced.
      Install.WantedBy = [ "sockets.target" ];
    };

    systemd.user.services.podman = lib.mkIf (cfg.runtime == "podman") {
      Unit = {
        Description = "Podman API service";
        Requires = [ "podman.socket" ];
        After = [ "podman.socket" ];
      };
      Service = {
        Type = lib.mkDefault "exec";
        KillMode = lib.mkDefault "process";
        ExecStart = lib.mkDefault "${pkgs.podman}/bin/podman system service";
        Restart = lib.mkDefault "on-failure";
        RestartSec = lib.mkDefault "5s";
      };
    };
  };
}
