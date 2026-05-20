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
#   darwinConfigurations.<name>       — one per machines/<name>/ (Darwin systems)
#   homeConfigurations.<user>@<arch>  — one per users/<username>/ × machine arch
#
# All framework NixOS and Home Manager modules are injected automatically.
# Consumers enable features by setting ft.* options in their machine/user files.
# No direct imports of ft-home module paths are needed or allowed.
# =============================================================================
{
  description = "Fast Track Nix - A Scalable, Beginner-Friendly Config Framework";

  inputs = {
    # Primary channel — all framework modules target nixos-unstable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Stable channel — available to consumers who need pinned-version packages.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    # Vendor hardware quirk modules (AMD, Intel, Raspberry Pi, etc.).
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    # CachyOS-optimised kernel builds — used by ft.kernel.cachyos.
    nix-cachyos.url = "github:xddxdd/nix-cachyos-kernel/release";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS support — only evaluated when darwinConfigurations are generated.
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    # Declarative disk partitioning, used with nixos-anywhere for remote installs.
    Disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Deploy NixOS to bare-metal or VMs over SSH without a live USB.
    Nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware detection — generates facter.json for reproducible hardware config.
    nixos-facter = {
      url = "github:numtide/nixos-facter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix User Repository — community overlays and packages.
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Age-encrypted secret management — used by ft.security.sops.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pre-built nix-index database for fast comma and command-not-found lookups.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Steam Deck / Jovian UI support — used by ft.profiles.gaming.enableLeanbackUI.
    jovian-nixos = {
      url = "github:jovian-experiments/jovian-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System-wide theming via Base16 schemes — used by ft.theme.
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;

      # Quality checks run by `nix flake check` and CI.
      mkChecks =
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          format =
            pkgs.runCommand "format-check"
              {
                nativeBuildInputs = with pkgs; [
                  nixfmt
                  deadnix
                  findutils
                ];
              }
              ''
                cp -r ${inputs.self}/. src
                find src \( -type f -o -type d \) -exec chmod u+w {} +
                find src -type f -name "*.nix" | sort | xargs -r nixfmt --check
                find src -type f -name "*.nix" | sort | xargs -r deadnix
                touch $out
              '';

          lint =
            pkgs.runCommand "statix-check"
              {
                nativeBuildInputs = [ pkgs.statix ];
              }
              ''
                statix check ${inputs.self}
                touch $out
              '';
        };

      # `nix fmt` entry-point — wraps treefmt for local dev use.
      # Uses writeShellScriptBin to avoid shellcheck build-time validation.
      mkFormatter =
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellScriptBin "format" ''
          export PATH="${
            pkgs.lib.makeBinPath (
              with pkgs;
              [
                treefmt
                nixfmt
                deadnix
              ]
            )
          }:$PATH"
          exec "${pkgs.treefmt}/bin/treefmt" "$@"
        '';

      # Dev shell for local formatting/linting: `nix develop`.
      mkDevShell =
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShell {
          packages = with pkgs; [
            treefmt
            nixfmt
            deadnix
            statix
          ];
        };
    in
    {
      lib.mkFlake = consumerInputs: import ./lib/generator.nix (inputs // consumerInputs);
      nixosModules.default = import ./modules/nixos;
      homeManagerModules.default = import ./modules/home;
      formatter = forAllSystems mkFormatter;
      devShells = forAllSystems (system: {
        default = mkDevShell system;
      });
      checks = forAllSystems mkChecks;
      packages = forAllSystems (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        in
        {
          inherit (pkgs) nixfmt deadnix;
        }
      );
    };
}
