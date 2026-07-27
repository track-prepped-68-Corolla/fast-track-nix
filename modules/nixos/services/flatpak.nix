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
      description = "Turns on the system Flatpak service and adds the Flathub remote. Once enabled, `services.flatpak.packages` (provided by nix-flatpak) becomes the place to declare system-wide Flatpak apps — set it in any machine file, profile, or other module, and every definition merges together automatically. Pair this with `ft.flatpak.frontend.enable` to also get a graphical Flathub browser.";
    };

    frontend = {
      enable = lib.mkEnableOption "graphical Flathub frontend" // {
        description = "Installs `ft.flatpak.frontend.package`, a graphical app for browsing and installing Flatpaks from Flathub.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kdePackages.discover;
        description = "The package providing the graphical Flathub browser.";
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

    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gtk ];
    };

    environment.systemPackages = lib.optional cfg.frontend.enable cfg.frontend.package;
  };
}
