{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ft.liveIso;
in
{
  options.ft.liveIso = {
    enable = lib.mkEnableOption "bootstrap live ISO environment" // {
      description = "Configures a NixOS live environment with all tools needed to provision a new machine via nixos-anywhere, disko, and nixos-facter. Build the ISO with lib.mkLiveIso; inject SSH keys and additional config via its extraModules argument.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorised for the root account on boot. Pass via extraModules in lib.mkLiveIso.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nixos-anywhere
      disko
      nixos-facter
      sops
      age
      just
      git
      neovim
      tmux
      curl
      jq
      parted
      util-linux
    ];

    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkDefault "yes";
        PasswordAuthentication = lib.mkDefault false;
      };
    };

    users.users.root.openssh.authorizedKeys.keys = lib.mkDefault cfg.authorizedKeys;

    users.motd = lib.mkDefault ''
      ┌─────────────────────────────────────────────────────────────────┐
      │  ft-home provisioning ISO                                       │
      │  nixos-anywhere  disko  nixos-facter  sops  age  just  git      │
      ├─────────────────────────────────────────────────────────────────┤
      │  1. git clone <your-consumer-repo> /root/config                 │
      │  2. cd /root/config                                             │
      │  3a. just bootstrap <name> <ip>      # remote install           │
      │  3b. just bootstrap-local <name>     # install on this machine  │
      │                                                                 │
      │  Run 'just --list' for all available recipes.                   │
      └─────────────────────────────────────────────────────────────────┘
    '';
  };
}
