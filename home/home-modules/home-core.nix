{ config, pkgs, ... }:

################################################################################
# HOME CORE (The Foundation)
# ------------------------------------------------------------------------------
# Mandatory settings shared by ALL users.
################################################################################

{
  # 1. Self-Management
  programs.home-manager.enable = true;

  # 2. Compatibility Lock
  home.stateVersion = "24.05";

  # 3. Auto-Home Path
  home.homeDirectory = "/home/${config.home.username}";
}