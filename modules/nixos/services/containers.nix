{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# OCI CONTAINER RUNTIME SUBSTRATE
#
# One module, four cells: {docker,podman} × {rootful,rootless}. The rootless
# scaffolding (dedicated service user, subuid/subgid maps, linger, user socket,
# DOCKER_HOST) is runtime-agnostic — only the daemon underneath differs. Apps
# such as ft.komodo layer on top and inherit the runtime via ft.containers.socket.
#
# Compose is always the genuine Docker Compose v2 Go binary (pkgs.docker-compose),
# driven through the Docker-API-compatible socket for BOTH backends — podman
# exposes one via dockerCompat (rootful) or its rootless user socket. Never
# podman-compose.
################################################################################

let
  cfg = config.ft.containers;

  # Docker-API-compatible socket the selected cell exposes. Rootful docker and
  # rootful podman (dockerCompat) both land at /var/run/docker.sock; rootless
  # puts the runtime's user socket under the service account's runtime dir.
  socketDefault =
    if cfg.rootless then
      "/run/user/${toString cfg.uid}/${
        if cfg.runtime == "podman" then "podman/podman.sock" else "docker.sock"
      }"
    else
      "/var/run/docker.sock";

  # /opt/containers and any Komodo/app tree must be writable by whoever the
  # daemon runs as: the service account when rootless, root otherwise.
  runtimeOwner = if cfg.rootless then cfg.user else "root";
in
{
  options.ft.containers = {
    enable = lib.mkEnableOption "OCI container runtime substrate" // {
      description = "Sets up a container runtime — Docker or Podman, running as root or rootless — along with the real Docker Compose v2 binary and, optionally, Distrobox. Other features, like ft.komodo, build on top of this and reach the daemon through the Docker-API-compatible socket this module provides.";
    };

    runtime = lib.mkOption {
      type = lib.types.enum [
        "docker"
        "podman"
      ];
      default = "podman";
      description = "Which container runtime to use. Podman is the recommended choice for rootless setups; both runtimes expose a Docker-API-compatible socket, so the real docker-compose binary works unchanged against either one.";
    };

    rootless = lib.mkOption {
      type = lib.types.bool;
      default = cfg.runtime == "podman";
      description = "Run the container runtime without root privileges. When enabled, a dedicated unprivileged account (ft.containers.user) is created with its own subuid/subgid ranges, kept logged in via systemd lingering, and given a user-level daemon socket that DOCKER_HOST points at — this runs `podman system service` or rootless dockerd depending on ft.containers.runtime. When disabled, the system daemon runs as root instead (and Podman gains its Docker-compatible socket via dockerCompat).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "podman";
      description = "Name of the unprivileged account created for rootless mode. Ignored when rootless = false.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Fixed UID/GID for the rootless service account. The rootless daemon's socket path is derived from this (/run/user/<uid>/...). Ignored when rootless = false.";
    };

    compose.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Installs the real Docker Compose v2 binary (pkgs.docker-compose), which drives either runtime through its Docker-API-compatible socket. podman-compose is never used.";
    };

    distrobox.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Installs Distrobox, for running containers from other Linux distributions as environments integrated with the host, on top of whichever runtime is selected.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/containers";
      description = "Base directory set up for docker-compose workloads and bind mounts. Owned by the rootless service account when rootless is enabled, otherwise owned by root.";
    };

    socket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = socketDefault;
      description = "Read-only: the Docker-API-compatible socket path exposed by whichever runtime and mode are active. Other features built on this module (e.g. ft.komodo) read this and use it as DOCKER_HOST.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # ── Common ──────────────────────────────────────────────────────────────
      {
        environment.systemPackages =
          lib.optional cfg.compose.enable pkgs.docker-compose
          ++ lib.optional cfg.distrobox.enable pkgs.distrobox;

        systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0750 ${runtimeOwner} ${runtimeOwner} -" ];
      }

      # ── Rootless: DOCKER_HOST for the whole system ──────────────────────────
      (lib.mkIf cfg.rootless {
        environment.sessionVariables.DOCKER_HOST = lib.mkDefault "unix://${cfg.socket}";
      })

      # ── Rootful docker ──────────────────────────────────────────────────────
      (lib.mkIf (!cfg.rootless && cfg.runtime == "docker") {
        virtualisation.docker = {
          enable = lib.mkDefault true;
          daemon.settings.storage-driver = lib.mkDefault "overlay2";
        };
      })

      # ── Rootful podman (Docker-compatible socket for compose) ───────────────
      (lib.mkIf (!cfg.rootless && cfg.runtime == "podman") {
        virtualisation.podman = {
          enable = lib.mkDefault true;
          dockerCompat = lib.mkDefault true;
          dockerSocket.enable = lib.mkDefault true;
        };
      })

      # ── Rootless: shared service-account scaffolding ────────────────────────
      (lib.mkIf cfg.rootless {
        # Some hardened kernels ship this sysctl disabled.
        boot.kernel.sysctl."kernel.unprivileged_userns_clone" = lib.mkDefault 1;

        users.groups.${cfg.user}.gid = lib.mkDefault cfg.uid;

        users.users.${cfg.user} = {
          isNormalUser = lib.mkDefault true;
          uid = lib.mkDefault cfg.uid;
          group = cfg.user;
          home = lib.mkDefault "/home/${cfg.user}";
          createHome = lib.mkDefault true;
          description = lib.mkDefault "Rootless container service account";
          # linger keeps the account's systemd user session alive without a login,
          # so its daemon socket is up at boot.
          linger = lib.mkDefault true;
          # Replaceable default ranges — a consumer redefining them should win
          # outright, not concatenate, so mkDefault is deliberate here.
          subUidRanges = lib.mkDefault [
            {
              startUid = 100000;
              count = 65536;
            }
          ];
          subGidRanges = lib.mkDefault [
            {
              startGid = 100000;
              count = 65536;
            }
          ];
        };
      })

      # ── Rootless podman: user socket + service ──────────────────────────────
      (lib.mkIf (cfg.rootless && cfg.runtime == "podman") {
        virtualisation.podman.enable = lib.mkDefault true;

        systemd.user.sockets.podman = {
          description = "Podman API socket";
          documentation = [ "man:podman-system-service(1)" ];
          listenStreams = [ "%t/podman/podman.sock" ];
          socketConfig.SocketMode = lib.mkDefault "0660";
          # List option: leave unwrapped so it merges rather than being replaced
          # (an override at normal priority would silently drop sockets.target).
          wantedBy = [ "sockets.target" ];
        };

        systemd.user.services.podman = {
          description = "Podman API service";
          documentation = [ "man:podman-system-service(1)" ];
          requires = [ "podman.socket" ];
          after = [ "podman.socket" ];
          serviceConfig = {
            Type = lib.mkDefault "exec";
            KillMode = lib.mkDefault "process";
            ExecStart = lib.mkDefault "${pkgs.podman}/bin/podman system service";
            Restart = lib.mkDefault "on-failure";
            RestartSec = lib.mkDefault "5s";
          };
        };
      })

      # ── Rootless docker: user-level dockerd for the service account ─────────
      #
      # nixpkgs' virtualisation.docker.rootless targets an interactive user; its
      # systemd --user docker.service is picked up by the lingering service
      # account's manager. setSocketVariable is left off so DOCKER_HOST has a
      # single definition (set in the common rootless block above).
      (lib.mkIf (cfg.rootless && cfg.runtime == "docker") {
        virtualisation.docker.rootless = {
          enable = lib.mkDefault true;
          setSocketVariable = lib.mkDefault false;
        };
      })
    ]
  );
}
