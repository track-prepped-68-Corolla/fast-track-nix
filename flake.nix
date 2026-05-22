# =============================================================================
# ft-home — Fast Track Nix Framework Flake
# =============================================================================
#
# This flake IS the framework. It is consumed as a flake input, not used
# directly. Consumers call lib.mkFlake from their own minimal flake.nix:
#
#   outputs = inputs @ { ft-home, ... }:
#     ft-home.lib.mkFlake inputs;
#
# That single call runs lib/generator.nix, which auto-discovers the consumer's
# machines/ and users/ directories and emits:
#   nixosConfigurations.<name>        — one per machines/<name>/
#   darwinConfigurations.<name>        — one per machines/<name>/ (Darwin systems)
#   homeConfigurations.<user>@<arch>  — one per users/<username>/ × machine arch
#
# All framework NixOS and Home Manager modules are injected automatically.
# Consumers enable features by setting ft.* options in their machine/user files.
# No direct imports of ft-home module paths are needed or allowed.
#
# Flake structure:
#   lib/inputs.nix          — all input declarations
#   lib/generator.nix       — consumer-facing machine/user discovery
#   lib/parts/checks.nix    — format + lint checks (nix flake check)
#   lib/parts/devshell.nix  — nix develop shell
#   lib/parts/formatter.nix — nix fmt entry-point
#   lib/parts/exports.nix   — lib.mkFlake, nixosModules, homeManagerModules, packages
# =============================================================================
{
  description = "Fast Track Nix - A Scalable, Beginner-Friendly Config Framework";

  inputs = import ./lib/inputs.nix;

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake inputs {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [
        ./lib/parts/checks.nix
        ./lib/parts/devshell.nix
        ./lib/parts/formatter.nix
        ./lib/parts/exports.nix
      ];
    };
}
