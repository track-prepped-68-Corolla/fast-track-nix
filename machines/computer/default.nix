# =============================================================================
# computer — Machine Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at machines/computer/default.nix
# and becomes nixosConfigurations.computer.
#
# WHAT GOES HERE
#   hardware-configuration.nix   machine-specific kernel modules and filesystems
#   Identity                     hostName, mainuser, superUsers
#   ft.* feature toggles         enable framework and consumer modules
#
# WHAT DOES NOT GO HERE
#   Do not import ft-home modules directly — the generator injects them.
#   Per-user Home Manager config belongs in users/<username>/default.nix.
# =============================================================================
{ ... }:

{
  # --- IDENTITY ---
  networking.hostName = "computer";

  mainuser = "guest";
  superUsers = [ "admin" ];
  users.mutableUsers = true;

  # --- FEATURE TOGGLES ---
  ft.boot.limine.enable = true;
  ft.desktop.cosmic.enable = true;
  ft.cli.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";
}
