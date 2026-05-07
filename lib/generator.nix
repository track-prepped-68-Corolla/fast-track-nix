inputs@{ nixpkgs, home-manager, darwin ? null, self, ... }:
let
  inherit (nixpkgs) lib;

  # Helper function to get a list of subdirectories in a given path
  getDirs = path:
    if builtins.pathExists path 
    then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else [];

  # ==========================================
  # 1. HOSTS DISCOVERY (Subdirectory Routing)
  # Expected structure: hosts/<architecture>/<hostname>
  # ==========================================
  hostsDir = self + "/hosts";
  hostSystems = getDirs hostsDir;

  # Build a flat list of all hosts across all system directories
  hostList = lib.flatten (map (system:
    let sysDir = hostsDir + "/${system}";
    in map (name: {
      inherit name system;
      path = sysDir + "/${name}";
      isDarwin = lib.strings.hasSuffix "darwin" system;
    }) (getDirs sysDir)
  ) hostSystems);

  # Separate them into NixOS and macOS lists
  nixosHosts = builtins.filter (x: !x.isDarwin) hostList;
  darwinHosts = builtins.filter (x: x.isDarwin) hostList;

  # Function to generate a NixOS system
  mkNixosHost = host: lib.nameValuePair host.name (lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [ 
      host.path 
      { nixpkgs.hostPlatform = lib.mkDefault host.system; } 
    ];
  });

  # Function to generate a macOS system
  mkDarwinHost = host: 
    assert lib.assertMsg (darwin != null) "The 'darwin' input is missing, but a macOS host (${host.name}) was discovered!";
    lib.nameValuePair host.name (darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };
      modules = [ 
        host.path 
        { nixpkgs.hostPlatform = lib.mkDefault host.system; }
      ];
  });

  # ==========================================
  # 2. HOME MANAGER DISCOVERY (Architecture Matrix)
  # Expected structure: homes/<username>
  # ==========================================
  homesDir = self + "/homes";
  homeUsers = getDirs homesDir;

  # Derive supported systems from declared hosts — no phantom configs for systems
  # that don't exist in the consumer's hosts/ tree
  supportedSystems = lib.unique (map (h: h.system) hostList);

  # Create a matrix of every user paired with every supported system
  homeMatrix = lib.flatten (map (user: 
    map (system: { inherit user system; }) supportedSystems
  ) homeUsers);

  # Function to generate a Home Manager configuration for a specific system
  mkHome = { user, system }: 
    lib.nameValuePair "${user}@${system}" (home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = { inherit inputs; };
      modules = [
        (homesDir + "/${user}")
      ];
    });

in
{
  # Construct the final flake outputs
  nixosConfigurations = builtins.listToAttrs (map mkNixosHost nixosHosts);
  darwinConfigurations = builtins.listToAttrs (map mkDarwinHost darwinHosts);
  homeConfigurations  = builtins.listToAttrs (map mkHome homeMatrix);
}
