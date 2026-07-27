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
      description = "Builds a NixOS live environment with everything needed to set up a new machine, using nixos-anywhere, disko, and nixos-facter. To produce an ISO, add a var/format marker file to the machine's directory (see flake-parts/lib/machines.nix) — the generator then emits it as packages.<system>.<name> instead of a nixosConfiguration. Add SSH keys via ft.liveIso.authorizedKeys in the machine's default.nix.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys allowed to log in as root when the live environment boots. Set this in the machine's default.nix.";
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
