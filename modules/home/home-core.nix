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
        description = "Activates the mandatory Home Manager foundation: sets stateVersion, homeDirectory, XDG base directories, genericLinux compatibility, and unfree packages. Must remain enabled for all other home modules to function.";
      };

      stateVersion = lib.mkOption {
        type = lib.types.str;
        description = "The Home Manager release version this user profile was *first created* on. Controls which state migration paths activate — set it once at user creation and never change it.";
      };

      genericLinux = lib.mkEnableOption "non-NixOS Linux compatibility" // {
        description = "Enables Home Manager's targets.genericLinux, which sources HM session variables into shell profiles and installs the per-user Nix profile path (~/.local/state/nix/profiles/home-path). Required for standalone Home Manager on non-NixOS Linux (Ubuntu, Fedora, etc.). Must be false when HM is used as a NixOS module (home-manager.nixosModules.home-manager): the install_profile activation step will fail because ~/.local/state/nix/profiles does not exist on a freshly-booted NixOS system.";
      };
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/nix/ft-home";
      description = "Absolute path to the consumer's flake repo root. Set in homes/<username>/default.nix.";
    };

    dotfiles.path = lib.mkOption {
      type = lib.types.str;
      default = "${config.ft.repoPath}/users/${config.home.username}/dotfiles";
      description = "Absolute path to this user's dotfiles directory.";
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
