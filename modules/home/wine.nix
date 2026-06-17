{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# WINE COMPATIBILITY MODULE (Home Manager)
################################################################################
#
# ft.wine — Home Manager counterpart of the NixOS ft.wine module. Same
# Bottles/Wine/Winetricks stack, installed into the user profile instead of
# the system closure. Useful on standalone Home Manager systems or non-NixOS
# distros.

let
  cfg = config.ft.wine;
in
{
  options.ft.wine = {
    enable = lib.mkEnableOption "Wine/Bottles compatibility stack" // {
      description = "Installs Bottles, Wine (WOW64 build), and Winetricks into the user profile for running Windows applications outside of Steam. Home Manager counterpart of the NixOS ft.wine module — use on standalone Home Manager systems or non-NixOS distros.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkDefault (
      with pkgs;
      [
        bottles
        wineWowPackages.stable
        winetricks
      ]
    );
  };
}
