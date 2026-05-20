{ pkgs, lib, config, ... }:

let
  cfg = config.ft.system.core;
in
{
  # -------------------------------------------------------------------------
  #  FAST TRACK NIX - BOILERPLATE & DEFAULTS
  # -------------------------------------------------------------------------

  options.ft.system.core.enable = lib.mkEnableOption "system core baseline" // {
    default = true;
    description = "Sets the system-wide baseline every host shares: stateVersion, NetworkManager, Bluetooth, CUPS/Avahi printing, flakes + nix-command, store auto-optimisation, timezone (America/New_York), locale (en_US.UTF-8), zsh shell, and core CLI packages. All values use mkDefault and can be overridden per host.";
  };

  options.ft.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "/nix/ft-home";
    description = "Absolute path to the consumer's flake repo root. Set this in your host file.";
  };

  config = lib.mkIf cfg.enable {

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
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
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
