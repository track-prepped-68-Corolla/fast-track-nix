# =============================================================================
# computer — Machine Configuration
# =============================================================================
#
# Discovered by lib/generator.nix at machines/computer/default.nix
# and becomes nixosConfigurations.computer.
#
# WHAT GOES HERE
#   hardware-configuration.nix   machine-specific kernel modules and filesystems
#   Identity                     hostName, ft.users.mainUser, ft.users.superUsers
#   ft.* feature toggles         enable framework and consumer modules
#
# WHAT DOES NOT GO HERE
#   Do not import ft-home modules directly — the generator injects them.
#   Per-user Home Manager config belongs in users/<username>/default.nix.
# =============================================================================
_:

{
  # --- IDENTITY ---
  networking.hostName = "computer";
  users.mutableUsers = true;

  # --- FILESYSTEM (placeholder — replace with disko or hardware-configuration.nix) ---
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "defaults"
      "size=2G"
      "mode=755"
    ];
  };

  boot.loader.systemd-boot.enable = true;

  # --- FEATURE TOGGLES ---
  ft = {
    core.stateVersion = "25.05";
    limine.enable = true;
    plasma.enable = true;
    cli.enable = true;
    users.mainUser = "guest";
    users.superUsers = [ "admin" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
