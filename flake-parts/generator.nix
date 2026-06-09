# =============================================================================
# ft-home Generator — flake-parts module
# =============================================================================
#
# Auto-discovers machines/ and users/ in inputs.self (the consumer's flake
# root) and emits nixosConfigurations, darwinConfigurations, and
# homeConfigurations. Consumed via ft-home.lib.mkFlake — not part of
# ft-home's own flake outputs.
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
#   ../modules/nixos is prepended to every nixosConfiguration so consumer
#   machine files never need explicit ft-home imports.
#   ../modules/home is prepended to every homeConfiguration similarly.
# =============================================================================
{ inputs, ... }:
let
  inherit (inputs) self nixpkgs home-manager;
  inherit (nixpkgs) lib;
  darwin = inputs.darwin or null;
  nixos-generators = inputs.nixos-generators or null;

  getDirs =
    path:
    if builtins.pathExists path then
      lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else
      [ ];

  # ==========================================
  # 1. MACHINES DISCOVERY
  # ==========================================
  machinesDir = self + "/machines";
  machineNames = getDirs machinesDir;

  mkMachineEntry =
    name:
    let
      factsFile = self + "/machines/${name}/var/facter.json";
      facter =
        if builtins.pathExists factsFile then builtins.fromJSON (builtins.readFile factsFile) else { };
      system = facter.system or "x86_64-linux";
      isDarwin = lib.hasSuffix "-darwin" system;
    in
    {
      inherit name system isDarwin;
      path = machinesDir + "/${name}";
    };

  machineList = map mkMachineEntry machineNames;
  nixosMachines = builtins.filter (x: !x.isDarwin) machineList;
  darwinMachines = builtins.filter (x: x.isDarwin) machineList;

  # ==========================================
  # 1b. IMAGE FORMAT DETECTION
  # ==========================================
  # machines/<name>/var/format — optional file whose content names a
  # nixos-generators format (e.g. "install-iso").  When present the
  # generator emits packages.<system>.<name> for that machine in
  # addition to nixosConfigurations.<name>.
  getMachineFormat =
    machine:
    let
      formatFile = machine.path + "/var/format";
    in
    if builtins.pathExists formatFile then lib.removeSuffix "\n" (builtins.readFile formatFile) else null;

  formattedMachines = builtins.filter (m: getMachineFormat m != null) nixosMachines;

  mkImagePackage =
    machine:
    assert lib.assertMsg (
      nixos-generators != null
    ) "nixos-generators input is required to build image packages but was not found";
    nixos-generators.nixosGenerate {
      pkgs = nixpkgs.legacyPackages.${machine.system};
      format = getMachineFormat machine;
      specialArgs = { inherit inputs; };
      modules = [
        inputs.Disko.nixosModules.disko
        inputs.microvm.nixosModules.host
        ../modules/nixos
        machine.path
        { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
      ];
    };

  # ==========================================
  # 2. USERS DISCOVERY
  # ==========================================
  usersDir = self + "/users";
  userNames = getDirs usersDir;

  localSystemFile = self + "/var/local/system";
  localSystem =
    if builtins.pathExists localSystemFile then
      lib.removeSuffix "\n" (builtins.readFile localSystemFile)
    else
      null;

  supportedSystems = lib.unique (
    (map (m: m.system) machineList) ++ lib.optional (localSystem != null) localSystem
  );

  userMatrix = lib.flatten (
    map (user: map (system: { inherit user system; }) supportedSystems) userNames
  );
in
{
  flake = {
    nixosConfigurations = builtins.listToAttrs (
      map (
        machine:
        lib.nameValuePair machine.name (
          lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              # Disko and microvm host module are captured in the closure here
              # (not via module args) so they are available before any module
              # imports are resolved.  Accessing inputs inside `imports` causes
              # infinite recursion when inputs is provided via _module.args
              # rather than specialArgs (e.g. in NixOS VM smoke tests).
              inputs.Disko.nixosModules.disko
              inputs.microvm.nixosModules.host
              ../modules/nixos
              machine.path
              { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
            ];
          }
        )
      ) nixosMachines
    );

    darwinConfigurations = builtins.listToAttrs (
      map (
        machine:
        assert lib.assertMsg (
          darwin != null
        ) "The 'darwin' input is missing, but a macOS machine (${machine.name}) was discovered!";
        lib.nameValuePair machine.name (
          darwin.lib.darwinSystem {
            specialArgs = { inherit inputs; };
            modules = [
              machine.path
              { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
            ];
          }
        )
      ) darwinMachines
    );

    homeConfigurations = builtins.listToAttrs (
      map (
        { user, system }:
        lib.nameValuePair "${user}@${system}" (
          home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.${system};
            extraSpecialArgs = { inherit inputs; };
            modules = [
              ../modules/home
              (usersDir + "/${user}")
            ];
          }
        )
      ) userMatrix
    );

    # Machines with a var/format file are built as image packages in addition
    # to their normal nixosConfiguration.  packages.<system>.<name> holds the
    # nixos-generators output (e.g. the .iso file for "install-iso").
    packages = lib.foldr (
      machine: acc:
      lib.recursiveUpdate acc { ${machine.system}.${machine.name} = mkImagePackage machine; }
    ) { } formattedMachines;
  };
}
