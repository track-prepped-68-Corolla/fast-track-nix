{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# WINE COMPATIBILITY MODULE
################################################################################
#
# ft.wine is two-level (grandfathered) — provides a self-contained Windows
# application compatibility stack. ft.profiles.* targets compound gaming/desktop
# profiles; ft.programs.* targets lightweight CLI tool installs. Neither fits
# a full Wine+Bottles environment, so ft.wine stands alone.

let
  cfg = config.ft.wine;
in
{
  options.ft.wine = {
    enable = lib.mkEnableOption "Wine/Bottles compatibility stack" // {
      description = "Installs Bottles, Wine (WOW64 build), and Winetricks for running Windows applications outside of Steam.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      bottles
      wineWowPackages.stable
      winetricks
    ];
  };
}
