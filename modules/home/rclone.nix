{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# RCLONE MOUNT (Home Manager)
# ------------------------------------------------------------------------------
# Per-user systemd service that mounts an rclone remote under $HOME via FUSE.
# Pairs with the NixOS ft.rclone module, which installs rclone/FUSE
# system-wide and enables fuse user_allow_other — this module owns the actual
# mount unit, since the generator emits standalone homeConfigurations and
# home-manager.users.* is not available here.
################################################################################

let
  cfg = config.ft.rclone;
  mountPath = "${config.home.homeDirectory}/${cfg.mountPoint}";

  mountScript = pkgs.writeShellScript "rclone-mount" ''
    exec ${pkgs.rclone}/bin/rclone mount ${lib.escapeShellArg "${cfg.remoteName}:"} ${lib.escapeShellArg mountPath} ${
      lib.concatMapStringsSep " " lib.escapeShellArg cfg.extraMountArgs
    }
  '';
in
{
  options.ft.rclone = {
    enable = lib.mkEnableOption "per-user rclone mount service" // {
      description = "Automatically mounts a cloud storage remote (via rclone) as a folder under your home directory, kept running by a systemd user service. This pairs with the NixOS `ft.rclone` module, which installs rclone and FUSE system-wide; this module handles the actual per-user mount.";
    };

    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
      example = "gdrive";
      description = "Name of the rclone remote to mount, as set up in your rclone config (e.g. with `rclone config`). This must match a remote that already exists.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "GoogleDrive";
      example = "GoogleDrive";
      description = "Name of the folder under your home directory where the remote gets mounted, e.g. `~/GoogleDrive`.";
    };

    extraMountArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--vfs-cache-mode"
        "writes"
      ];
      description = "Extra command-line arguments passed to `rclone mount`, added after the remote and mount-point arguments — useful for things like cache mode or buffer size.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.rclone-mount = {
      Unit = {
        Description = "rclone mount of ${cfg.remoteName}: at ${mountPath}";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = lib.mkDefault "notify";
        ExecStartPre = lib.mkDefault "${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg mountPath}";
        ExecStart = lib.mkDefault "${mountScript}";
        ExecStop = lib.mkDefault "${pkgs.fuse}/bin/fusermount -u ${lib.escapeShellArg mountPath}";
        Restart = lib.mkDefault "on-failure";
        RestartSec = lib.mkDefault "10s";
      };
      Install.WantedBy = lib.mkDefault [ "default.target" ];
    };
  };
}
