{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# ROOTLESS PODMAN SERVICE USER
################################################################################

let
  cfg = config.ft.services.podmanRootless;
in
{
  options.ft.services.podmanRootless = {
    enable = lib.mkEnableOption "rootless Podman service user" // {
      description = "Creates a dedicated unprivileged 'podman' user with subuid/subgid mappings, enables cgroup v2, configures a persistent user-level Podman socket via systemd lingering, and provisions /opt/containers. Installs docker-compose pointed at the rootless socket.";
    };
    uid = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Fixed UID and GID assigned to the podman service user. Derives the Podman socket path at /run/user/<uid>/podman/podman.sock for DOCKER_HOST.";
    };
  };

  config = lib.mkIf cfg.enable {
    # cgroup v2 unified hierarchy required for rootless per-cgroup resource delegation
    systemd.enableUnifiedCgroupHierarchy = lib.mkDefault true;
    systemd.enableCgroupAccounting = lib.mkDefault true;

    # Some kernels (e.g. hardened variants) ship with this sysctl disabled
    boot.kernel.sysctl."kernel.unprivileged_userns_clone" = lib.mkDefault 1;

    users.groups.podman.gid = lib.mkDefault cfg.uid;

    users.users.podman = {
      isNormalUser = lib.mkDefault true;
      uid = lib.mkDefault cfg.uid;
      group = lib.mkDefault "podman";
      home = lib.mkDefault "/home/podman";
      createHome = lib.mkDefault true;
      description = lib.mkDefault "Rootless Podman service account";
      # linger keeps the user's systemd session alive without an active interactive login
      linger = lib.mkDefault true;
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

    virtualisation.podman.enable = lib.mkDefault true;

    # User-level socket definition; WantedBy=sockets.target auto-starts it when
    # a user session begins. Only the podman user has lingering, so only its
    # session starts at boot.
    systemd.user.sockets.podman = {
      description = "Podman API socket";
      documentation = [ "man:podman-system-service(1)" ];
      listenStreams = [ "%t/podman/podman.sock" ];
      socketConfig.SocketMode = lib.mkDefault "0660";
      wantedBy = lib.mkDefault [ "sockets.target" ];
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

    # Derived from cfg.uid — socket path is never hardcoded
    environment.sessionVariables.DOCKER_HOST = lib.mkDefault "unix:///run/user/${toString cfg.uid}/podman/podman.sock";

    environment.systemPackages = [ pkgs.docker-compose ];

    # Base directory for docker-compose.yml workloads
    systemd.tmpfiles.rules = [ "d /opt/containers 0750 podman podman -" ];
  };
}
