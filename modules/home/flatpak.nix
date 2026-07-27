{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# FLATPAK (Home Manager) — per-user declarative app list
################################################################################

let
  cfg = config.ft.flatpak;
in
{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  options.ft.flatpak = {
    enable = lib.mkEnableOption "per-user Flatpak app declarations" // {
      description = "Registers the Flathub remote for this user's own Flatpak installs and lets you declare which Flatpak apps you want via `services.flatpak.packages` (from nix-flatpak). You can set that list in this user's base config or in any of their `profiles/<name>/` submodules — all the lists get merged together. The host machine also needs `ft.flatpak.enable` (the NixOS side) so the Flatpak service and desktop portal actually exist.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.remotes = lib.mkDefault [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
  };
}
