{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ft.core;
in
{
  # -------------------------------------------------------------------------
  #  FAST TRACK NIX - BOILERPLATE & DEFAULTS
  # -------------------------------------------------------------------------

  options.ft.core = {
    enable = lib.mkEnableOption "system core baseline" // {
      default = true;
      description = "The baseline every machine starts from: network management, Bluetooth, network printing, zsh as the shell, and a set of everyday CLI tools. Every value here is just a default, so any host can override individual pieces.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "The NixOS release this machine was originally installed on. NixOS uses this to decide which one-time upgrade steps to run at boot, so getting it wrong can trigger changes you don't want. Set it once when the machine is created and leave it alone after that.";
    };
  };

  options.ft.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "/nix/ft-home";
    description = "Absolute path to your consumer repo on disk. Set this in your machine's config file.";
  };

  config = lib.mkIf cfg.enable {

    # --- 1. SYSTEM IDENTITY ---
    # Plain assignment, not mkDefault: cfg.stateVersion has no default (every
    # consumer must set it explicitly), so this is always a deliberate,
    # consumer-directed value. It must outrank nixpkgs' own mkDefault (e.g.
    # installation-cd-base.nix's mkDefault lib.trivial.release for ISO image
    # machines) rather than conflict with it at equal priority.
    system.stateVersion = cfg.stateVersion;

    # --- 2. HARDWARE & CONNECTIVITY ---
    networking.networkmanager.enable = lib.mkDefault true;
    hardware.bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;
    };

    # --- 3. PRINTING & DISCOVERY ---
    services = {
      printing.enable = lib.mkDefault true;
      avahi = {
        enable = lib.mkDefault true;
        nssmdns4 = true;
        openFirewall = lib.mkDefault true;
      };
    };

    # --- 4. NIX SETTINGS ---
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    # mkDefault so the NixOS testing framework's nixpkgs/read-only.nix (which
    # activates when node.pkgs is provided and sets nixpkgs.config as a
    # types.unique option) takes precedence over this definition in tests.
    # In production, where read-only.nix is not active, this default applies.
    nixpkgs.config = lib.mkDefault { allowUnfree = true; };

    # --- 5. LOCALE ---
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
