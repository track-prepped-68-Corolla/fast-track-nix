{
  description = "Fast Track Nix - A Scalable, Beginner-Friendly Config";

  inputs = {
    # --- Core Dependencies ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-cachyos.url = "github:xddxdd/nix-cachyos-kernel/release";

    # --- Home & Theming ---
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # --- Extras ---
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # Note: These are Home Manager modules (User Desktop Configs)
    cosmic-manager.url = "github:HeitorAugustoLN/cosmic-manager";
    cosmic-manager.inputs.nixpkgs.follows = "nixpkgs";
    cosmic-manager.inputs.home-manager.follows = "home-manager";

    jovian-nixos.url = "github:jovian-experiments/jovian-nixos";
    jovian-nixos.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      # --- CONFIGURATION VARIABLES ---

      # 1. HOSTNAMES
      # To add a new machine, just add its name here and create
      # the folder: ./hosts/<name>/default.nix
      systems = [
        "strix"
        "talos"
        "t14"
        "spec"
        "proto"
      ];

      # --- LIBRARY IMPORTS ---
      lib = nixpkgs.lib;

      # This allows us to access 'inputs' (like nix-cachyos) inside any module
      # without manually importing them again.
      specialArgs = { inherit inputs; };
    in
    {
      # --- SYSTEM BUILDER ---
      #
      # Standard NixOS configs list every host manually:
      #   nixosConfigurations.spec = lib.nixosSystem { ... };
      #   nixosConfigurations.proto = lib.nixosSystem { ... };
      #
      # We use 'lib.genAttrs' to AUTOMATE this.
      # It loops over the 'systems' list above and generates a config for each one.

      nixosConfigurations = lib.genAttrs systems (
        host:
        lib.nixosSystem {
          inherit specialArgs;
          modules = [
            # 1. The Core Aggregator
            # This imports all the common "plumbing" (Home Manager, Stylix, Sops)
            ./nixos/modules/default.nix

            # 2. The Host Specific Config
            # This dynamically imports the folder matching the hostname
            ./nixos/hosts/${host}/default.nix

            # 3. Import the nix-index module
            inputs.nix-index-database.nixosModules.nix-index

            # 4. Flake Overlays
            # We inject the NUR overlay here so pkgs.nur is available system-wide
            (
              { inputs, ... }:
              {
                nixpkgs.overlays = [ inputs.nur.overlays.default ];
              }
            )
          ];
        }
      );
    };
}
