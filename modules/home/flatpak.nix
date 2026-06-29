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
      description = "Registers the Flathub remote for this user's `--user` Flatpak installs and exposes `services.flatpak.packages` (nix-flatpak) as the per-user declarative app list — set it in this user's base config or any of their `profiles/<name>/` submodules; the lists from every definition are merged. Requires the host's `ft.flatpak.enable` (NixOS) so the Flatpak service and desktop portal are present.";
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
