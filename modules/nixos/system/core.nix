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

  meta = {
    description = "Sets the system-wide baseline every host shares: NetworkManager, Bluetooth, flakes + nix-command, store auto-optimisation, locale (en_US.UTF-8), zsh shell, and core CLI packages. All values use mkDefault and can be overridden per host.";
    default = true;
  };

  options.ft.core = {
    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "The NixOS release version this machine was first installed on. Controls state migration paths — set it once at machine creation and never change it.";
    };
  };

  options.ft.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "/nix/ft-home";
    description = "Absolute path to the consumer's flake repo root. Set this in your host file.";
  };

  config = lib.mkIf cfg.enable {
    system.stateVersion = lib.mkDefault cfg.stateVersion;

    networking.networkmanager.enable = lib.mkDefault true;
    hardware.bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;
    };

    services = {
      printing.enable = lib.mkDefault true;
      avahi = {
        enable = lib.mkDefault true;
        nssmdns4 = true;
        openFirewall = lib.mkDefault true;
      };
    };

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    nixpkgs.config = lib.mkDefault { allowUnfree = true; };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

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
