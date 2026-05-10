{ config, pkgs, lib, ... }:

################################################################################
# HOME CORE (The Foundation)
# ------------------------------------------------------------------------------
# Mandatory settings shared by ALL users.
################################################################################

{
  options.ft.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Absolute path to the consumer's flake repo root. Set in homes/<username>/default.nix.";
  };

  config = {
    programs.home-manager.enable = true;
    home.stateVersion = "24.05";
    home.homeDirectory = "/home/${config.home.username}";
    targets.genericLinux.enable = true;
    xdg.enable = true;
    nixpkgs.config.allowUnfree = true;
  };
}
