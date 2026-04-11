inputs@{ nixpkgs, home-manager, ... }:
let
  inherit (nixpkgs) lib;
  
  # --- 1. GLOBALS ---
  defaultSystem = "x86_64-linux";

  # --- 2. NIXOS DISCOVERY (The Hosts) ---
  hostsDir = ../hosts;
  hostDirs = if builtins.pathExists hostsDir 
             then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir hostsDir))
             else [];

  mkHost = name: lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      (hostsDir + "/${name}")
    ];
  };

  # --- 3. HOME MANAGER DISCOVERY (The Homes) ---
  homesDir = ../homes;
  homeDirs = if builtins.pathExists homesDir 
             then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir homesDir))
             else [];

  mkHome = name: home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.${defaultSystem};
    
    # Note: Home Manager uses 'extraSpecialArgs' instead of 'specialArgs'
    extraSpecialArgs = { inherit inputs; };
    
    modules = [
      (homesDir + "/${name}")
    ];
  };

in
{
  # --- 4. THE FINAL OUTPUTS ---
  nixosConfigurations = lib.genAttrs hostDirs mkHost;
  homeConfigurations  = lib.genAttrs homeDirs mkHome;
}