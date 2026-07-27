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
      description = "Installs rclone and FUSE for the whole system and allows FUSE mounts to be shared with other users, so a per-user rclone mount service can expose a cloud drive (like Google Drive) at the configured mount point.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "GoogleDrive";
      example = "GoogleDrive";
      description = "The name of the folder your per-user rclone mount service should mount to, e.g. a Home Manager service mounting under `~/<mountPoint>`. This is just a naming convention — this module doesn't create the mount itself.";
    };

    remoteName = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
      example = "gdrive";
      description = "The rclone remote name your per-user mount service should use, e.g. `rclone mount <remoteName>: ...`. Again, just a naming convention — this module doesn't create the mount itself.";
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
