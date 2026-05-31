# =============================================================================
# VM Smoke Test Packages
# =============================================================================
#
# Exposes framework self-tests as packages.x86_64-linux.vm-* so they stay
# out of nix flake check (which targets checks.*) and can be run selectively:
#
#   nix build -L --option system-features "nixos-test kvm benchmark big-parallel" \
#     .#vm-bulk-pool-load
#
# Only exposed on x86_64-linux — NixOS VM tests require that host system.
# =============================================================================
{ inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    pkgs.lib.mkIf (system == "x86_64-linux") {
      packages = import ../tests/vm {
        inherit inputs;
        inherit (inputs) nixpkgs;
      };
    };
}
