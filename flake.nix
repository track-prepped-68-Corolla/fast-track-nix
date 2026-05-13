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
# hosts/ and homes/ directories and emits:
#   nixosConfigurations.<hostname>    — one per hosts/<arch>/<hostname>/
#   darwinConfigurations.<hostname>   — one per hosts/<arch>-darwin/<hostname>/
#   homeConfigurations.<user>@<arch>  — one per homes/<username>/ × host arch
#
# All framework NixOS and Home Manager modules are injected automatically.
# Consumers enable features by setting ft.* options in their host/home files.
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
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:numtide/nixos-facter/e43c4459184a39ed6f3aa746a49170ae79d93bcd";
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

  outputs = ftHomeInputs: {
    # Called by consumers: merges framework inputs with consumer inputs (consumer
    # keys take precedence), then runs the generator so inputs.self resolves to
    # the consumer's repo and directory scanning works correctly.
    lib.mkFlake = consumerInputs:
      import ./lib/generator.nix {
        inputs  = ftHomeInputs // consumerInputs;
        ftNixos = ftHomeInputs.self.nixosModules.default;
        ftHome  = ftHomeInputs.self.homeManagerModules.default;
      };

    # Single NixOS module that auto-imports everything under modules/nixos/.
    # Injected into every nixosConfiguration and darwinConfiguration.
    nixosModules.default = import ./modules/nixos;

    # Single Home Manager module that auto-imports everything under modules/home/.
    # Injected into every homeConfiguration.
    homeManagerModules.default = import ./modules/home;
  };
}
