{
  lib,
  pkgs,
  config,
  ...
}:

################################################################################
# KAROUSEL — scrollable-tiling KWin script
#
# Packaged upstream in nixpkgs as kdePackages.karousel (installs into
# $out/share/kwin/scripts via kpackagetool6, discovered via XDG_DATA_DIRS once
# added to home.packages), so this module just consumes it directly.
#
# Installing the script doesn't activate it: ft.plasmaManager owns writing
# kwinrc's [Plugins] karouselEnabled key, hence the hard dependency below.
################################################################################

let
  cfg = config.ft.karousel;
in
{
  options.ft.karousel = {
    enable = lib.mkEnableOption "Karousel scrollable-tiling KWin script" // {
      description = "Installs the Karousel scrollable-tiling script for KWin and turns it on through `kwinrc`. Requires `ft.plasmaManager.enable`, since that's what manages the `kwinrc` Plugins settings declaratively.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.plasmaManager.enable;
        message = "ft.karousel requires ft.plasmaManager.enable = true";
      }
    ];

    home.packages = [ pkgs.kdePackages.karousel ];

    programs.plasma.configFile.kwinrc.Plugins.karouselEnabled = lib.mkDefault true;
  };
}
