inputs@{ nixpkgs, home-manager, darwin ? null, self, ... }:
let
  inherit (nixpkgs) lib;

  # Helper function to get a list of subdirectories in a given path
  getDirs = path:
    if builtins.pathExists path
    then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else [];

  # ==========================================
  # 1. HOSTS DISCOVERY (Flat Structure)
  # Expected structure: hosts/<hostname>
  # System derived from hosts/<hostname>/var/facter.json
  # ==========================================
  hostsDir  = self + "/hosts";
  hostNames = getDirs hostsDir;

  mkHostEntry = name:
    let
      factsFile = self + "/hosts/${name}/var/facter.json";
      facter    = if builtins.pathExists factsFile
                  then builtins.fromJSON (builtins.readFile factsFile)
                  else {};
      system    = facter.system or "x86_64-linux";
      isDarwin  = lib.hasSuffix "-darwin" system;
    in {
      inherit name system isDarwin;
      path = hostsDir + "/${name}";
    };

  hostList    = map mkHostEntry hostNames;
  nixosHosts  = builtins.filter (x: !x.isDarwin) hostList;
  darwinHosts = builtins.filter (x: x.isDarwin) hostList;

  mkNixosHost = host: lib.nameValuePair host.name (lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      ../modules/nixos
      host.path
      { nixpkgs.hostPlatform = lib.mkDefault host.system; }
    ];
  });

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

  # Local machine system — written by bootstrap to var/local/system.
  # Ensures a home config is generated for the current machine even when
  # it has no corresponding host entry (e.g. standalone HM on non-NixOS).
  localSystemFile = self + "/var/local/system";
  localSystem     = if builtins.pathExists localSystemFile
                    then lib.removeSuffix "\n" (builtins.readFile localSystemFile)
                    else null;

  # Derive supported systems from declared hosts, plus the local machine.
  supportedSystems = lib.unique (
    (map (h: h.system) hostList)
    ++ lib.optional (localSystem != null) localSystem
  );

  # Create a matrix of every user paired with every supported system
  homeMatrix = lib.flatten (map (user:
    map (system: { inherit user system; }) supportedSystems
  ) homeUsers);

  mkHome = { user, system }:
    lib.nameValuePair "${user}@${system}" (home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ../modules/home
        (homesDir + "/${user}")
      ];
    });

in
{
  nixosConfigurations = builtins.listToAttrs (map mkNixosHost nixosHosts);
  darwinConfigurations = builtins.listToAttrs (map mkDarwinHost darwinHosts);
  homeConfigurations  = builtins.listToAttrs (map mkHome homeMatrix);
}
