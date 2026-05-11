{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# NFS CLIENT MODULE
# ------------------------------------------------------------------------------
# This module provides a flexible way to configure NFS (Network File System)
# client mounts. It ensures necessary NFS utilities are installed, RPCBIND
# is enabled, and dynamically creates `fileSystems` entries based on user
# defined mounts.
################################################################################

let
  cfg = config.ft.services.nfs;
in
{
  options.ft.services.nfs = {
    enable = lib.mkEnableOption "NFS Client mount management";

    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            remotePath = lib.mkOption {
              type = lib.types.str;
              description = "Remote path of the NFS share (e.g., server:/path).";
            };
            mountPoint = lib.mkOption {
              type = lib.types.str;
              description = "Local mount point for the NFS share.";
            };
          };
        }
      );
      default = { };
      description = "Attribute set of NFS mounts to configure.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.nfs-utils ];
    services.rpcbind.enable = true;
    boot.supportedFilesystems = [ "nfs" ];

    fileSystems = lib.mapAttrs' (
      name: value:
      lib.nameValuePair "${value.mountPoint}" {
        device = "${value.remotePath}";
        fsType = "nfs";
        options = [
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=600"
          "nfsvers=4.1"
          "soft"
          "intr"
          "_netdev"
        ];
      }
    ) cfg.mounts;
  };
}
