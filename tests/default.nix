# =============================================================================
# ft-home Test Suite
# =============================================================================
#
# Entry point for all ft-home tests. Each sub-file returns an attrset of
# derivations; this file merges them and prefixes names to avoid collisions.
#
# Usage (once wired into flake.nix checks):
#   nix build .#checks.x86_64-linux.test-generator
#   nix build .#checks.x86_64-linux.test-host-facts
#   nix build .#checks.x86_64-linux.test-home-core
#   nix build .#checks.x86_64-linux.test-flake-outputs
#
# Standalone evaluation (without flake integration):
#   nix build -f tests/default.nix --argstr system x86_64-linux
# =============================================================================
{ pkgs, lib }:

let
  prefix = name: tests: lib.mapAttrs' (n: v: lib.nameValuePair "${name}-${n}" v) tests;
in
(prefix "generator" (import ./generator.nix { inherit pkgs lib; }))
// (prefix "host-facts" (import ./host-facts.nix { inherit pkgs lib; }))
// (prefix "home-core" (import ./home-core.nix { inherit pkgs lib; }))
// (prefix "flake-outputs" (import ./flake-outputs.nix { inherit pkgs lib; }))