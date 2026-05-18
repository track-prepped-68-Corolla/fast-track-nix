# =============================================================================
# strix — Host Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at hosts/strix/default.nix
# and becomes nixosConfigurations.strix.
#
# WHAT GOES HERE
#   hardware-configuration.nix   machine-specific kernel modules and filesystems
#   modules/nixos                consumer NixOS modules (auto-gated by ft.*)
#   Identity                     hostName, mainuser, superUsers
#   ft.* feature toggles         enable framework and consumer modules
#
# WHAT DOES NOT GO HERE
#   Do not import ft-home modules directly — the generator injects them.
#   Per-user Home Manager config belongs in homes/<username>/default.nix.
# =============================================================================
{ lib, ... }:

{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  # --- IDENTITY ---
  networking.hostName = "computer";

  # mainuser is read by user.nix, sops.nix, gaming.nix, virt.nix, and others.
  mainuser = "guest";
  superUsers = [ "admin" ];
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.boot.limine.enable = true;
  ft.desktop.cosmic.enable = true;
  ft.mullet.enable = true;
  ft.hardware.gpu.enable = true;
  ft.hardware.yubikey.enable = true;
  ft.cli.enable = true;
  ft.keepass.enable = true;

  ft.security.sops = {
    enable = true;
    useTPM = true;
  };

  ft.kernel.cachyos =  {
    enable = true;
    variant = "bore";
  };

  ft.hardware.facter = {
    enable = true;
    reportPath = ./facter.json;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  # U2F key pre-registered. Activate hardware auth by also setting
  # ft.hardware.yubikey.enable = true when the key is physically present.
  ft.hardware.yubikey.u2fMapping = "";
    ];
  };
}
