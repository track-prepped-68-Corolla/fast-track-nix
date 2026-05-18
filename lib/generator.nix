# =============================================================================
# ft-home Generator
# =============================================================================
#
# Called by ft-home.lib.mkFlake with the merged input set
# (ftHomeInputs // consumerInputs). Consumer keys take precedence, so
# consumers can shadow any framework input. Critically, inputs.self is
# the CONSUMER's flake self — all directory scanning uses the consumer
# repo root, not ft-home's.
#
# MACHINE DISCOVERY
#   Scans inputs.self/machines/<name>/ for directories.
#   System is read from machines/<name>/var/facter.json (facter.system).
#   Names whose system ends in "-darwin" produce darwinConfigurations;
#   all others produce nixosConfigurations.
#   Falls back to "x86_64-linux" if facter.json is absent (pre-scan).
#
# USER DISCOVERY
#   Scans inputs.self/users/<username>/ for directories.
#   Each user is paired with every system found in machines/ plus the
#   local machine's system (read from var/local/system, written by
#   bootstrap). This ensures home configs exist for standalone HM users
#   who have no machines/ entry.
#
# MODULE INJECTION
#   ../modules/nixos is prepended to every nixosConfiguration/
#   darwinConfiguration so consumer machine files never need explicit
#   ft-home imports.
#   ../modules/home is prepended to every homeConfiguration similarly.
# =============================================================================
inputs@{ nixpkgs, home-manager, darwin ? null, self, ... }:
let
  inherit (nixpkgs) lib;

  # Helper function to get a list of subdirectories in a given path
  getDirs = path:
    if builtins.pathExists path
    then lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else [];

  # ==========================================
  # 1. MACHINES DISCOVERY (Flat Structure)
  # Expected structure: machines/<name>
  # System derived from machines/<name>/var/facter.json
  # ==========================================
  machinesDir  = self + "/machines";
  machineNames = getDirs machinesDir;

  mkMachineEntry = name:
    let
      factsFile = self + "/machines/${name}/var/facter.json";
      facter    = if builtins.pathExists factsFile
                  then builtins.fromJSON (builtins.readFile factsFile)
                  else {};
      system    = facter.system or "x86_64-linux";
      isDarwin  = lib.hasSuffix "-darwin" system;
    in {
      inherit name system isDarwin;
      path = machinesDir + "/${name}";
    };

  machineList    = map mkMachineEntry machineNames;
  nixosMachines  = builtins.filter (x: !x.isDarwin) machineList;
  darwinMachines = builtins.filter (x: x.isDarwin) machineList;

  mkNixosMachine = machine: lib.nameValuePair machine.name (lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      ../modules/nixos
      machine.path
      { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
    ];
  });

  mkDarwinMachine = machine:
    assert lib.assertMsg (darwin != null) "The 'darwin' input is missing, but a macOS machine (${machine.name}) was discovered!";
    lib.nameValuePair machine.name (darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };
      modules = [
        machine.path
        { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
      ];
  });

  # ==========================================
  # 2. USERS DISCOVERY (Architecture Matrix)
  # Expected structure: users/<username>
  # ==========================================
  usersDir  = self + "/users";
  userNames = getDirs usersDir;

  # Local machine system — written by bootstrap to var/local/system.
  # Ensures a home config is generated for the current machine even when
  # it has no corresponding machines/ entry (e.g. standalone HM on non-NixOS).
  localSystemFile = self + "/var/local/system";
  localSystem     = if builtins.pathExists localSystemFile
                    then lib.removeSuffix "\n" (builtins.readFile localSystemFile)
                    else null;

  # Derive supported systems from declared machines, plus the local machine.
  supportedSystems = lib.unique (
    (map (m: m.system) machineList)
    ++ lib.optional (localSystem != null) localSystem
  );

  # Create a matrix of every user paired with every supported system
  userMatrix = lib.flatten (map (user:
    map (system: { inherit user system; }) supportedSystems
  ) userNames);

  mkUser = { user, system }:
    lib.nameValuePair "${user}@${system}" (home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ../modules/home
        (usersDir + "/${user}")
      ];
    });

in
{
  nixosConfigurations  = builtins.listToAttrs (map mkNixosMachine nixosMachines);
  darwinConfigurations = builtins.listToAttrs (map mkDarwinMachine darwinMachines);
  homeConfigurations   = builtins.listToAttrs (map mkUser userMatrix);
}
