# =============================================================================
# VM Test Shared Library (Framework Self-Tests)
# =============================================================================
#
# Provides a base NixOS module config and test runner for all framework VM
# smoke tests:
#
#   baseConfig — framework modules only, loaded from inputs.self
#   mkTest     — wraps pkgs.testers.runNixOSTest with node.specialArgs
#                so every node receives `inputs` via specialArgs rather than
#                _module.args, preventing infinite recursion when inputs is
#                referenced inside `imports`.
#
# These tests exercise fast-track-nix modules directly from the local checkout
# (inputs.self) rather than a consumer's pinned version. mergedInputs is not
# needed here — there is no consumer layer; inputs IS the framework's inputs.
# =============================================================================
{ inputs, nixpkgs }:

let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
in
{
  mkTest =
    spec:
    pkgs.testers.runNixOSTest (
      nixpkgs.lib.recursiveUpdate spec {
        node.specialArgs.inputs = inputs;
      }
    );

  # Framework modules only — imported from inputs.self so tests always target
  # the local checkout rather than any consumer's pinned version.
  #
  # disko-btrfs: hardware-dependent disk layout, no VM test.
  # gaming: unconditionally imports jovian-nixos, whose overlay.nix sets
  #   nixpkgs.overlays at normal priority — collides with nixpkgs/read-only.nix
  #   (types.unique) activated by runNixOSTest. Exempt per CLAUDE.md.
  baseConfig =
    { ... }:
    {
      imports = [ inputs.self.nixosModules.default ];
      disabledModules = [
        "${inputs.self}/modules/nixos/hardware/disko-btrfs.nix"
        "${inputs.self}/modules/nixos/profiles/gaming.nix"
      ];
      ft.system.core.stateVersion = "25.05";
      ft.users.initialPasswords.admin = "test";
      hardware.bluetooth.enable = false;
    };
}
