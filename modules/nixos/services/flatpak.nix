{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# FLATPAK SERVICE + FLATHUB REMOTE
################################################################################

let
  cfg = config.ft.flatpak;
in
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  options.ft.flatpak = {
    enable = lib.mkEnableOption "Flatpak application support" // {
      description = "Enables the system Flatpak service and registers the Flathub remote. Once enabled, `services.flatpak.packages` (provided by nix-flatpak) becomes the declarative install surface for system-wide apps — set it in any machine file, profile, or other submodule and the lists from every definition are merged automatically. Pair with `ft.flatpak.frontend.enable` for a graphical Flathub browser.";
    };

    frontend = {
      enable = lib.mkEnableOption "graphical Flathub frontend" // {
        description = "Installs `ft.flatpak.frontend.package`, a GUI application for browsing and installing Flatpaks from Flathub.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kdePackages.discover;
        description = "Package providing the graphical Flathub frontend.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;
      remotes = lib.mkDefault [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];
    };

    xdg.portal.enable = lib.mkDefault true;

    environment.systemPackages = lib.optional cfg.frontend.enable cfg.frontend.package;
  };
}
