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
    environment.systemPackages = lib.mkDefault [ pkgs.nfs-utils ];
    services.rpcbind.enable = lib.mkDefault true;
    boot.supportedFilesystems = lib.mkDefault [ "nfs" ];

    systemd.automounts = lib.mapAttrsToList (
      _name: value: {
        where = value.mountPoint;
        wantedBy = [ "multi-user.target" ];
        automountConfig.TimeoutIdleSec = "600";
      }
    ) cfg.mounts;

    systemd.mounts = lib.mapAttrsToList (
      _name: value: {
        what = value.remotePath;
        where = value.mountPoint;
        type = "nfs";
        options = "nfsvers=4.1,soft,intr,_netdev";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
      }
    ) cfg.mounts;
  };
}
