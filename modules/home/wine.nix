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

  # Work around an upstream nixpkgs breakage: python3Packages.patool 4.0.5,
  # pulled in transitively by Bottles, currently fails its pytest suite on the
  # framework's nixpkgs pin (file/libmagic reports `.tar.bz2` as
  # application/x-bzip2, so patool's MIME/tar-detection tests error out). The
  # broken check aborts Bottles' build. Scope the fix to a locally extended
  # package set so only the packages this module installs are affected, and
  # skip patool's own tests until the fix lands upstream.
  wpkgs = pkgs.extend (
    _: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_: pyprev: {
          patool = pyprev.patool.overridePythonAttrs (_: {
            doCheck = false;
          });
        })
      ];
    }
  );
in
{
  options.ft.wine = {
    enable = lib.mkEnableOption "Wine/Bottles compatibility stack" // {
      description = "Installs Bottles, Wine (the WOW64 build), and Winetricks so you can run Windows applications outside of Steam. This is the Home Manager counterpart of the NixOS `ft.wine` module, meant for standalone Home Manager systems or non-NixOS distros.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkDefault [
      wpkgs.bottles
      wpkgs.wineWowPackages.stable
      wpkgs.winetricks
    ];
  };
}
