{ lib, ... }:

{
  imports = [
    # 1. The hardware scan for this specific machine
    ./hardware-configuration.nix

    # 2. The Shared Module Library (Magic Collator)
    ../../modules/nixos
  ];

  networking.hostName = "strix";

  # Assuming you define these custom options in your modules
  mainuser = "joe";
  superUsers = [ "joe" ];

  # --- FEATURE TOGGLES ---
  ft.desktop.cosmic.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}