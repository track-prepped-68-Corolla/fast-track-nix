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
      description = "Runs a systemd user service that mounts an rclone remote at a path under $HOME via FUSE. Home Manager counterpart of the NixOS ft.rclone module, which installs rclone/FUSE system-wide and enables fuse user_allow_other; this module owns the actual per-user mount unit.";
    };

    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
      example = "gdrive";
      description = "rclone remote name to mount, as configured in this user's rclone config (e.g. via `rclone config`). Must match an existing remote.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "GoogleDrive";
      example = "GoogleDrive";
      description = "Directory name under $HOME where the remote is mounted (e.g. ~/GoogleDrive).";
    };

    extraMountArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--vfs-cache-mode"
        "writes"
      ];
      description = "Extra arguments passed to `rclone mount`, appended after the remote and mount-point arguments (e.g. cache mode, buffer size).";
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
