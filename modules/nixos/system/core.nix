{ pkgs, lib, ... }:

{
  # -------------------------------------------------------------------------
  #  FAST TRACK NIX - BOILERPLATE & DEFAULTS
  # -------------------------------------------------------------------------
  #
  #  This file sets the baseline configuration for EVERY machine you build.
  #
  #  The Goal:
  #  1. Keep host files clean (only unique hardware/features go there).
  #  2. Ensure consistent settings across your fleet (same timezone, same locale).
  #  3. Enable modern Nix features (Flakes) by default.
  #
  #  Note: We use 'lib.mkDefault' for almost everything here.
  #  This allows you to override these settings in a host file if necessary.
  # -------------------------------------------------------------------------

  options = {
    ft.repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/nix/ft-home";
      description = "Absolute path to the consumer's flake repo root. Set this in your host file.";
    };
  };

  config = {

    # --- 1. SYSTEM IDENTITY ---
    system.stateVersion = "24.05";

    # --- 2. HARDWARE & CONNECTIVITY ---
    networking.networkmanager.enable = lib.mkDefault true;
    hardware.bluetooth.enable = lib.mkDefault true;
    hardware.bluetooth.powerOnBoot = lib.mkDefault true;

    # --- 3. PRINTING & DISCOVERY ---
    services.printing.enable = lib.mkDefault true;
    services.avahi = {
      enable = lib.mkDefault true;
      nssmdns4 = true;
      openFirewall = lib.mkDefault true;
    };

    # --- 4. NIX SETTINGS ---
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.auto-optimise-store = true;
    nixpkgs.config.allowUnfree = true;

    # --- 5. TIME & LOCALE ---
    time.timeZone = lib.mkDefault "America/New_York";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    # --- 6. CORE PACKAGES ---
    programs.zsh.enable = true;

    environment.systemPackages = with pkgs; [
      nano
      git
      curl
      wget
      htop
      tmux
      home-manager
      lix
      nh
      nvd
      nix-output-monitor
      nixfmt
      findutils
      delta
    ];
  };
}
