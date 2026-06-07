{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# RCLONE MODULE — cloud storage tooling
# ------------------------------------------------------------------------------
# Installs rclone and FUSE and enables user_allow_other so a per-user rclone
# mount service (declared in the user's home config) can expose a cloud remote
# to other users/processes. The mount unit itself lives in the user's home
# configuration, not here — the generator emits standalone homeConfigurations,
# so home-manager.users.* is not a valid NixOS option in this setup.
################################################################################

let
  cfg = config.ft.rclone;
in
{
  options.ft.rclone = {
    enable = lib.mkEnableOption "rclone cloud storage tooling" // {
      description = "Installs rclone and FUSE system-wide and enables fuse user_allow_other, so a per-user rclone mount service can expose a cloud remote (e.g. Google Drive) under the configured mount point.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "GoogleDrive";
      description = "Default mount-point name a consumer's rclone mount service can reference.";
    };

    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
      description = "Default rclone remote name a consumer's rclone mount service can reference.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.rclone
      pkgs.fuse
    ];
    programs.fuse.userAllowOther = lib.mkDefault true;
  };
}
