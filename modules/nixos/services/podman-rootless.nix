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
  cfg = config.ft."podman-rootless";
in
{
  meta.description = "Creates a dedicated unprivileged 'podman' user with subuid/subgid mappings, enables cgroup v2, configures a persistent user-level Podman socket via systemd lingering, and provisions /opt/containers. Installs docker-compose pointed at the rootless socket.";

  options.ft."podman-rootless" = {
    uid = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Fixed UID and GID assigned to the podman service user.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl."kernel.unprivileged_userns_clone" = lib.mkDefault 1;

    users.groups.podman.gid = lib.mkDefault cfg.uid;

    users.users.podman = {
      isNormalUser = lib.mkDefault true;
      uid = lib.mkDefault cfg.uid;
      group = "podman";
      home = lib.mkDefault "/home/podman";
      createHome = lib.mkDefault true;
      description = lib.mkDefault "Rootless Podman service account";
      linger = lib.mkDefault true;
      subUidRanges = lib.mkDefault [ { startUid = 100000; count = 65536; } ];
      subGidRanges = lib.mkDefault [ { startGid = 100000; count = 65536; } ];
    };

    virtualisation.podman.enable = lib.mkDefault true;

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

    environment.sessionVariables.DOCKER_HOST = lib.mkDefault "unix:///run/user/${toString cfg.uid}/podman/podman.sock";
    environment.systemPackages = [ pkgs.docker-compose ];
    systemd.tmpfiles.rules = [ "d /opt/containers 0750 podman podman -" ];
  };
}
