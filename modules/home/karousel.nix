{
  lib,
  pkgs,
  config,
  ...
}:

################################################################################
# KAROUSEL — scrollable-tiling KWin script
#
# Karousel is not packaged in nixpkgs. The upstream release tarball already
# matches the layout KWin's KPackage loader expects (metadata.json + contents/),
# so it's installed verbatim into $out/share/kwin/scripts/karousel, discovered
# via XDG_DATA_DIRS once added to home.packages — the same convention nixpkgs
# uses for its `polonium` KWin script package.
#
# Installing the script doesn't activate it: ft.plasmaManager owns writing
# kwinrc's [Plugins] karouselEnabled key, hence the hard dependency below.
################################################################################

let
  cfg = config.ft.karousel;

  karousel = pkgs.callPackage (
    { stdenvNoCC, fetchurl, lib }:
    stdenvNoCC.mkDerivation {
      pname = "kwin-script-karousel";
      version = "0.17";
      src = fetchurl {
        url = "https://github.com/peterfajdiga/karousel/releases/download/v0.17/karousel_0_17.tar.gz";
        hash = "sha256-SS4pYtwOUQ5HeaDu38KqMRwu4+S2YhZI6uYO2+ML0cM=";
      };
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/kwin/scripts/karousel
        cp -r ./* $out/share/kwin/scripts/karousel/
        runHook postInstall
      '';
      meta = {
        description = "Scrollable tiling extension for KWin";
        homepage = "https://github.com/peterfajdiga/karousel";
        license = lib.licenses.gpl3Only;
        platforms = lib.platforms.linux;
      };
    }
  ) { };
in
{
  options.ft.karousel = {
    enable = lib.mkEnableOption "Karousel scrollable-tiling KWin script" // {
      description = "Installs the Karousel KWin script and enables it via kwinrc. Requires `ft.plasmaManager.enable` so the kwinrc Plugins key is managed declaratively.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.plasmaManager.enable;
        message = "ft.karousel requires ft.plasmaManager.enable = true";
      }
    ];

    home.packages = [ karousel ];

    programs.plasma.configFile.kwinrc.Plugins.karouselEnabled = lib.mkDefault true;
  };
}
