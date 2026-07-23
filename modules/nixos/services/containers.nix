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
      description = "Sets up a Docker or Podman runtime — rootful or rootless — with the real Docker Compose v2 binary and optional Distrobox. Apps like ft.komodo build on top and reach the daemon via the Docker-API-compatible socket this module exposes.";
    };

    runtime = lib.mkOption {
      type = lib.types.enum [
        "docker"
        "podman"
      ];
      default = "podman";
      description = "OCI runtime. Podman is recommended for rootless use; both expose a Docker-API-compatible socket so the genuine docker-compose binary drives either unchanged.";
    };

    rootless = lib.mkOption {
      type = lib.types.bool;
      default = cfg.runtime == "podman";
      description = "Run the runtime rootless. When true, a dedicated unprivileged service account (ft.containers.user) gets subuid/subgid maps, systemd lingering, and a user-level daemon socket, with DOCKER_HOST pointed at it — running `podman system service` or rootless dockerd per ft.containers.runtime. When false the system daemon runs as root (podman gains dockerCompat + the docker socket).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "podman";
      description = "Name of the unprivileged service account created for rootless mode. Ignored when rootless = false.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Fixed UID and GID for the rootless service account. The rootless daemon socket path derives from it (/run/user/<uid>/...). Ignored when rootless = false.";
    };

    compose.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the genuine Docker Compose v2 binary (pkgs.docker-compose). It drives either runtime through the Docker-API-compatible socket; podman-compose is never used.";
    };

    distrobox.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install Distrobox for running other-distribution containers as host-integrated environments on top of the selected runtime.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/containers";
      description = "Base directory provisioned for docker-compose and bind-mount workloads. Owned by the service account when rootless, otherwise root.";
    };

    socket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = socketDefault;
      description = "Read-only: the Docker-API-compatible socket path the active cell exposes. Consumed by apps built on this module (e.g. ft.komodo) as DOCKER_HOST.";
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
