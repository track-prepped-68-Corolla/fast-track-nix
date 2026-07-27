{ config, lib, ... }:

################################################################################
# HOME CORE (The Foundation)
# ------------------------------------------------------------------------------
# Mandatory settings shared by ALL users.
# Declares the two central path options so no other module needs to.
################################################################################

let
  cfg = config.ft.core;
in
{
  options.ft = {
    core = {
      enable = lib.mkEnableOption "home manager core settings" // {
        default = true;
        description = "Turns on the required Home Manager foundation that every other module depends on: it sets `stateVersion`, the home directory, XDG base directories, generic-Linux compatibility, and allows unfree packages. This needs to stay enabled for the other home modules to work.";
      };

      stateVersion = lib.mkOption {
        type = lib.types.str;
        description = "The Home Manager release this user profile was originally created on. Home Manager uses this to decide which one-time state migrations to run, so getting it wrong can trigger changes you don't want. Set it once when the profile is created and leave it alone after that.";
      };

      genericLinux = lib.mkEnableOption "non-NixOS Linux compatibility" // {
        description = "Turns on Home Manager's `targets.genericLinux`, which loads its session variables into your shell profiles and sets up the per-user Nix profile path (`~/.local/state/nix/profiles/home-path`). You need this when running standalone Home Manager on a non-NixOS Linux distro (Ubuntu, Fedora, etc.). Leave it off when Home Manager is used as a NixOS module (`home-manager.nixosModules.home-manager`) — turning it on there fails, because `~/.local/state/nix/profiles` doesn't exist on a freshly-booted NixOS system.";
      };
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/nix/ft-home";
      description = "The absolute path to your consumer flake repo's root directory. Set this in `homes/<username>/default.nix`.";
    };

    dotfiles.path = lib.mkOption {
      type = lib.types.str;
      default = "${config.ft.repoPath}/users/${config.home.username}/dotfiles";
      description = "The absolute path to this user's dotfiles directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;
    home = {
      inherit (cfg) stateVersion;
      homeDirectory = "/home/${config.home.username}";
    };
    targets.genericLinux.enable = lib.mkDefault cfg.genericLinux;
    xdg.enable = true;
    nixpkgs.config.allowUnfree = true;

    # Make GUI apps installed into the user's Home Manager profile (home.packages,
    # e.g. via the ft.mullet escape hatch) appear in the desktop launcher.
    #
    # Standalone Home Manager installs home.packages into config.home.profileDirectory
    # (~/.nix-profile). On NixOS the graphical session (display manager -> Plasma/COSMIC)
    # runs under the systemd --user manager and never sources hm-session-vars.sh, so the
    # profile's share/applications never reaches XDG_DATA_DIRS and those apps get no
    # .desktop entry. environment.d IS imported by systemd --user, so exporting
    # XDG_DATA_DIRS there reaches the graphical session. The current-system and /usr/share
    # dirs are restated so the base menu is never lost if XDG_DATA_DIRS is unset when
    # systemd --user evaluates this; the trailing ${XDG_DATA_DIRS} preserves anything
    # already present (duplicate entries are harmless to XDG lookup).
    #
    # Skipped under targets.genericLinux, where Home Manager wires session variables
    # itself and /run/current-system does not exist.
    xdg.configFile."environment.d/10-ft-hm-profile.conf" =
      lib.mkIf (!config.targets.genericLinux.enable)
        {
          text = ''
            XDG_DATA_DIRS=${config.home.profileDirectory}/share:/run/current-system/sw/share:/usr/local/share:/usr/share:''${XDG_DATA_DIRS}
          '';
        };
  };
}
