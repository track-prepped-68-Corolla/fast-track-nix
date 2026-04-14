inputs@{ nixpkgs, home-manager, ... }:
let
  inherit (nixpkgs) lib;

  # --- 1. NIXOS DISCOVERY ---
  hostsDir = ../hosts;
  hostDirs = if builtins.pathExists hostsDir 
             then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir hostsDir))
             else [];

  mkHost = name: lib.nixosSystem {
    # System is usually defined inside the host's configuration.nix via nixpkgs.hostPlatform
    specialArgs = { inherit inputs; };
    modules = [
      (hostsDir + "/${name}")
    ];
  };

  # --- 2. HOME MANAGER DISCOVERY ---
  homesDir = ../homes;
  homeDirs = if builtins.pathExists homesDir 
             then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir homesDir))
             else [];

  mkHome = name: home-manager.lib.homeManagerConfiguration {
    # It's better to instantiate pkgs based on a system defined per-home, 
    # but defaulting to x86_64-linux here is okay if they only use one architecture.
    pkgs = nixpkgs.legacyPackages."x86_64-linux";
    extraSpecialArgs = { inherit inputs; };
    modules = [
      (homesDir + "/${name}")
    ];
  };

in
{
  nixosConfigurations = lib.genAttrs hostDirs mkHost;
  homeConfigurations  = lib.genAttrs homeDirs mkHome;
}