{ config, pkgs, lib, ... }:

################################################################################
# HOME CORE (The Foundation)
# ------------------------------------------------------------------------------
# Mandatory settings shared by ALL users.
################################################################################

{
  programs.home-manager.enable = true;
  home.stateVersion = "24.05";
  home.homeDirectory = "/home/${config.home.username}";
  targets.genericLinux.enable = true;
  xdg.enable = true;
  nixpkgs.config.allowUnfree = true;
}
