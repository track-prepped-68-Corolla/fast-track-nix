# =============================================================================
# Framework VM Smoke Tests — Entry Point
# =============================================================================
#
# Merges all per-module test files into a single attrset of
# packages.x86_64-linux.vm-* derivations.
#
# Run a single test locally:
#   nix build -L --no-link \
#     --option system-features "nixos-test kvm benchmark big-parallel" \
#     .#vm-bulk-pool-load
#
# Requirements: x86_64-linux host with /dev/kvm available.
# =============================================================================
{ inputs, nixpkgs }:

let
  inherit (nixpkgs) lib;
  args = { inherit inputs nixpkgs; };
in
lib.foldl lib.recursiveUpdate { } (
  map (f: import f args) [
    ./bulk-pool.nix
  ]
)
