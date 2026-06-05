{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# NFS CLIENT MODULE
################################################################################

let
  cfg = config.ft.nfs;
in
{
  options.ft.nfs = {
    enable = lib.mkEnableOption "NFS Client mount management" // {
      description = "Configures NFS client mounts declared under `ft.nfs.mounts`. Each entry specifies a `remotePath` (e.g. server:/share) and a `mountPoint`, and is auto-mounted on demand with a 10-minute idle timeout via systemd.automount.";
    };

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
      _name: value:
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
