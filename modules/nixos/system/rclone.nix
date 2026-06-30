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
      example = "GoogleDrive";
      description = "Mount-point name a consumer's per-user rclone mount service references (e.g. a home-manager systemd user service mounting under ~/<mountPoint>). Convention only — this module does not create the mount itself.";
    };

    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
      example = "gdrive";
      description = "rclone remote name a consumer's per-user mount service references (e.g. `rclone mount <remoteName>: ...`). Convention only — this module does not create the mount itself.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.rclone
      pkgs.fuse
    ];
    programs.fuse.userAllowOther = lib.mkDefault true;
    # programs.fuse.userAllowOther alone does not reliably generate /etc/fuse.conf
    # in all nixpkgs-unstable versions; write it explicitly so the FUSE kernel
    # module honours allow_other mounts regardless of the NixOS fuse module version.
    environment.etc."fuse.conf".text = lib.mkDefault "user_allow_other\n";
  };
}
