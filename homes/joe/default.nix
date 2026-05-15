{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home
  ];

  home.username = "joe";
  ft.primaryHost = "strix";

  # ft.lazyvim.enable  = true;   # planned — module not yet implemented
  # ft.catppuccin.enable = true;  # planned — module not yet implemented

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages = with pkgs; [
    fastfetch
    htop
    micro
    yazi

    brave
    kitty
    vesktop
    signal-desktop
    slack
    localsend

    github-desktop
    vscodium
    direnv
    nixfmt

    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.krita
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.openscad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.freecad
    inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.blender
    libreoffice

    mangohud
    heroic
    lutris
    discord
  ];
}
