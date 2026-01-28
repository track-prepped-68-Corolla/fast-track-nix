{
  description = "Fast Track Nix - A Scalable, Beginner-Friendly Config";

  inputs = {
    # --- Core Dependencies ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-cachyos.url = "github:xddxdd/nix-cachyos-kernel/release";

    # --- Home & Theming ---
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # --- Extras & Desktops ---
    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Note: These are Home Manager modules (User Desktop Configs)
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";

    cosmic-manager.url = "github:HeitorAugustoLN/cosmic-manager";
    cosmic-manager.inputs.nixpkgs.follows = "nixpkgs";
    cosmic-manager.inputs.home-manager.follows = "home-manager";
    
    jovian-nixos.url = "github:jovian-experiments/jovian-nixos";
    jovian-nixos.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      # --- CONFIGURATION VARIABLES ---
      
      # 1. HOSTNAMES
      # To add a new machine, just add its name here and create 
      # the folder: ./hosts/<name>/default.nix
      systems = [ 
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
      
      nixosConfigurations = lib.genAttrs systems (host: 
        lib.nixosSystem {
          inherit specialArgs;
          modules = [
            # 1. The Core Aggregator 
            # This imports all the common "plumbing" (Home Manager, Stylix, Sops)
            ./modules/default.nix

            # 2. The Host Specific Config
            # This dynamically imports the folder matching the hostname
            ./hosts/${host}/default.nix

            # 3. User Definitions
            # Instead of a separate file, we define users directly here for visibility.
            # This maps to options defined in modules/system/user.nix
            {
              mainuser = "driver";
              superUsers = [ "admin" ];
              normalUsers = [ "guest" ];
            }
          ];
        }
      );
    };
}