{
  inputs,
  pkgs,
  config,
  ...
}:

{
  # -------------------------------------------------------------------------
  #  THE MODULE HUB
  # -------------------------------------------------------------------------
  #  This file acts as the "Aggregator" for your configuration.
  #
  #  Instead of cluttering your 'flake.nix' with 10 different import lines,
  #  we import them all here. Your flake only needs to import this one file.
  # -------------------------------------------------------------------------

  imports = [
    # --- 1. INTERNAL MODULES (Our Code) ---

    # The "Boilerplate": Sets defaults for Boot, Networking, Time, etc.
    ./system/core.nix

    # The "Logic": Generates user accounts based on variables.
    ./system/user.nix

    # oci containers
    ./system/containers.nix

    ./apps/default.nix

    # The desktop environment and display manager. turn it on by adding with ft.desktop.cosmic.enable = true;
    ./system/cosmic.nix

    ./hardware/vm.nix

    # profiles
    ./profiles/gaming.nix

    ./system/just.nix

    ./apps/mullet.nix

    # --- 2. EXTERNAL MODULES (From Flake Inputs) ---
    # These bring in tools from the internet that we defined in flake.nix.

    # Home Manager: The bridge that lets NixOS manage user config.
    inputs.home-manager.nixosModules.default

    # Stylix: The system-wide theming engine.
    inputs.stylix.nixosModules.stylix

    # Sops: The secrets manager (for encryption).
    inputs.sops-nix.nixosModules.sops

    # Jovian: Steam Deck UI and hardware optimizations.
    inputs.jovian-nixos.nixosModules.default
  ];

  # -------------------------------------------------------------------------
  #  ARCHITECTURAL NOTE: DESKTOP MANAGERS
  # -------------------------------------------------------------------------
  #  You might notice that 'plasma-manager' and 'cosmic-manager' are missing.
  #
  #  That is intentional!
  #
  #  Those are "Home Manager Modules", not "System Modules".
  #  They configure your personal desktop settings (panels, wallpapers), not
  #  the Operating System itself.
  #
  #  You must import them inside your 'users/<name>/home.nix' file instead.
  # -------------------------------------------------------------------------
}
