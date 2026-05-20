# =============================================================================
# ft-home Test Suite — Entry Point
# =============================================================================
#
# Aggregates all unit tests into a single Nix derivation that can be run with:
#
#   nix-build tests/default.nix --arg nixpkgs '<nixpkgs>'
#
# or included in the flake's checks output:
#
#   checks.<system>.unit-tests
#
# Each test file uses lib.runTests, which returns {} on success and throws a
# descriptive error on failure. We sequence each result via builtins.seq into
# a final runCommand derivation so evaluation failures surface at build time.
# =============================================================================
{ nixpkgs ? import <nixpkgs> { } }:

let
  pkgs = if nixpkgs ? legacyPackages then nixpkgs.legacyPackages.x86_64-linux else nixpkgs;
  lib = pkgs.lib;

  # Run each test file and collect results.  lib.runTests returns {} when all
  # tests pass or throws (with test names and diffs) on the first failure.
  generatorResults = import ./generator.nix { inherit lib pkgs; };
  hostFactsResults = import ./host-facts.nix { inherit lib pkgs; };

  # Verify both results are empty attrsets (lib.runTests contract).
  allResultsOk =
    generatorResults == { } && hostFactsResults == { };

in
pkgs.runCommand "ft-home-unit-tests"
  { }
  (
    if allResultsOk then
      ''
        echo "All ft-home unit tests passed."
        touch $out
      ''
    else
      builtins.throw "ft-home unit tests failed: ${builtins.toJSON { inherit generatorResults hostFactsResults; }}"
  )