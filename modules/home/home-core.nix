{ config, lib, ... }:

################################################################################
# HOME CORE (The Foundation)
# ------------------------------------------------------------------------------
# Mandatory settings shared by ALL users.
# Declares the two central path options so no other module needs to.
################################################################################

let
  cfg = config.ft.home.core;
in
{
  options.ft.home.core.enable = lib.mkEnableOption "home manager core settings" // {
    default = true;
    description = "Activates the mandatory Home Manager foundation: sets stateVersion, homeDirectory, XDG base directories, genericLinux compatibility, and unfree packages. Must remain enabled for all other home modules to function.";
  };

  options.ft.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "/nix/ft-home";
    description = "Absolute path to the consumer's flake repo root. Set in homes/<username>/default.nix.";
  };

  options.ft.dotfiles.path = lib.mkOption {
    type = lib.types.str;
    default = "${config.ft.repoPath}/homes/${config.home.username}/dotfiles";
    description = "Absolute path to this user's dotfiles directory.";
  };

  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;
    home.stateVersion = "24.05";
    home.homeDirectory = "/home/${config.home.username}";
    targets.genericLinux.enable = true;
    xdg.enable = true;
    nixpkgs.config.allowUnfree = true;
  };
}
