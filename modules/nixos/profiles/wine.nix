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
# ft.wine — self-contained Windows application compatibility stack.

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
