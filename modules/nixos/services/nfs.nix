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
      description = "Sets up NFS client mounts declared under `ft.nfs.mounts`. Each entry gives a `remotePath` (e.g. server:/share) and a `mountPoint`, and is mounted on demand — with a 10-minute idle timeout — via systemd's automount.";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            remotePath = lib.mkOption {
              type = lib.types.str;
              description = "Remote path of the NFS share (e.g. server:/path).";
            };
            mountPoint = lib.mkOption {
              type = lib.types.str;
              description = "Local mount point where the NFS share appears.";
            };
          };
        }
      );
      default = { };
      description = "The set of NFS mounts to configure.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.mkDefault [ pkgs.nfs-utils ];
    services.rpcbind.enable = lib.mkDefault true;
    boot.supportedFilesystems = lib.mkDefault [ "nfs" ];

    systemd.units =
      lib.mapAttrs' (
        _name: value:
        let
          # Derive the systemd unit name from the mount point:
          # strip leading "/" then replace remaining "/" with "-".
          unitName = lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" value.mountPoint);
        in
        lib.nameValuePair "${unitName}.automount" {
          wantedBy = [ "multi-user.target" ];
          text = ''
            [Unit]
            Description=Automount ${value.mountPoint}

            [Automount]
            Where=${value.mountPoint}
            TimeoutIdleSec=600
          '';
        }
      ) cfg.mounts
      // lib.mapAttrs' (
        _name: value:
        let
          unitName = lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" value.mountPoint);
        in
        lib.nameValuePair "${unitName}.mount" {
          text = ''
            [Unit]
            Description=Mount ${value.mountPoint}
            After=network-online.target
            Wants=network-online.target

            [Mount]
            What=${value.remotePath}
            Where=${value.mountPoint}
            Type=nfs
            Options=nfsvers=4.1,soft,intr,_netdev
          '';
        }
      ) cfg.mounts;
  };
}
