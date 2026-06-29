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
#   lib/generator.nix       — consumer-facing machine/user discovery
#   lib/parts/checks.nix    — format + lint checks (nix flake check)
#   lib/parts/devshell.nix  — nix develop shell
#   lib/parts/formatter.nix — nix fmt entry-point
#   lib/parts/exports.nix   — lib.mkFlake, nixosModules, homeManagerModules, packages
# =============================================================================
{
  description = "Fast Track Nix - A Scalable, Beginner-Friendly Config Framework";

  inputs = {
    # Primary channel — all framework modules target nixos-unstable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # GPU manager using eBPF LSM hooks — used by ft.cardwire.
    cardwire = {
      url = "github:OpenGamingCollective/cardwire";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Stable channel — available to consumers who need pinned-version packages.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    # Vendor hardware quirk modules (AMD, Intel, Raspberry Pi, etc.).
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    # CachyOS-optimised kernel builds — used by ft.cachyos.
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

    # NixOS module that consumes a facter.json report (hardware.facter.*).
    # Lives in a separate, dependency-free repo from the nixos-facter CLI tool;
    # required by ft.facter.
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    # Nix User Repository — community overlays and packages.
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Age-encrypted secret management — used by ft.sops.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pre-built nix-index database for fast comma and command-not-found lookups.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System-wide theming via Base16 schemes — used by ft.theme.
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative KDE Plasma settings via Home Manager — used by ft.plasmaManager.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Declarative Flatpak remotes and package lists — used by ft.flatpak.
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Lightweight VMs (Firecracker, QEMU, Cloud Hypervisor) — used by ft.dockervm.
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Native, Raycast-compatible launcher for Linux — used by ft.vicinae.
    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Opt-in state persistence on tmpfs root systems — used by ft.diskBtrfs.impermanence.
    impermanence.url = "github:nix-community/impermanence";

    # Official Nous Research hermes-agent flake — provides nixosModules.default.
    hermes-agent.url = "github:NousResearch/hermes-agent";

    # Colmena fleet deployment — consumed by flake-parts/colmena.nix to emit the
    # colmenaHive output (lib.makeHive).
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Comin — pull-based GitOps daemon, wrapped by the ft.gitops module.
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos-images — builds the per-machine kexec installer image (flake-parts/kexec.nix).
    nixos-images = {
      url = "github:nix-community/nixos-images";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Python packaging trio for the in-development ft_py CLI (scripts/ft_py) —
    # builds the uv.lock-pinned workspace with pure Nix. Framework-internal for
    # now (devShell + a not-yet-consumer-facing package); not part of
    # lib.mkFlake's consumer-facing import list.
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [
        ./flake-parts
      ];
    };
}
