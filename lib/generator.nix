{ inputs, ftNixos, ftHome }:
let
  inherit (inputs.nixpkgs) lib;

  darwin = inputs.darwin or null;

  # Helper function to get a list of subdirectories in a given path
  getDirs = path:
    if builtins.pathExists path
    then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else [];

  # ==========================================
  # 1. HOSTS DISCOVERY (Subdirectory Routing)
  # Expected structure: hosts/<architecture>/<hostname>
  # ==========================================
  hostsDir = inputs.self + "/hosts";
  hostSystems = getDirs hostsDir;

  hostList = lib.flatten (map (system:
    let sysDir = hostsDir + "/${system}";
    in map (name: {
      inherit name system;
      path = sysDir + "/${name}";
      isDarwin = lib.strings.hasSuffix "darwin" system;
    }) (getDirs sysDir)
  ) hostSystems);

  nixosHosts  = builtins.filter (x: !x.isDarwin) hostList;
  darwinHosts = builtins.filter (x:  x.isDarwin) hostList;

  mkNixosHost = host: lib.nameValuePair host.name (lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      ftNixos
      host.path
      { nixpkgs.hostPlatform = lib.mkDefault host.system; }
    ];
  });

  mkDarwinHost = host:
    assert lib.assertMsg (darwin != null) "The 'darwin' input is missing, but a macOS host (${host.name}) was discovered!";
    lib.nameValuePair host.name (darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ftNixos
        host.path
        { nixpkgs.hostPlatform = lib.mkDefault host.system; }
      ];
    });

  # ==========================================
  # 2. HOME MANAGER DISCOVERY (Architecture Matrix)
  # Expected structure: homes/<username>
  # ==========================================
  homesDir = inputs.self + "/homes";
  homeUsers = getDirs homesDir;

  supportedSystems = lib.unique (map (h: h.system) hostList);

  # Cross-product: every user paired with every discovered host arch so
  # home configs are available on all systems the consumer runs.
  homeMatrix = lib.flatten (map (user:
    map (system: { inherit user system; }) supportedSystems
  ) homeUsers);

  mkHome = { user, system }:
    lib.nameValuePair "${user}@${system}" (inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ftHome
        (homesDir + "/${user}")
      ];
    });

in
{
  nixosConfigurations = builtins.listToAttrs (map mkNixosHost nixosHosts);
  darwinConfigurations = builtins.listToAttrs (map mkDarwinHost darwinHosts);
  homeConfigurations  = builtins.listToAttrs (map mkHome homeMatrix);
}
