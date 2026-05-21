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
#
# CHECKS
#   Format (treefmt) and lint (statix) checks are emitted under
#   checks.<system>.{format,lint} for every supported system so that
#   `nix flake check` in a consumer repo runs the full quality gate.
# =============================================================================
inputs@{
  nixpkgs,
  home-manager,
  darwin ? null,
  self,
  ...
}:
let
  inherit (nixpkgs) lib;

  getDirs =
    path:
    if builtins.pathExists path then
      lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else
      [ ];

  # ==========================================
  # 1. MACHINES DISCOVERY (Flat Structure)
  # Expected structure: machines/<name>
  # System derived from machines/<name>/var/facter.json
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

  mkNixosMachine =
    machine:
    lib.nameValuePair machine.name (
      lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ../modules/nixos
          machine.path
          { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
        ];
      }
    );

  mkDarwinMachine =
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
    );

  # ==========================================
  # 2. USERS DISCOVERY (Architecture Matrix)
  # Expected structure: users/<username>
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

  checkSystems = lib.unique (supportedSystems ++ [ "x86_64-linux" ]);

  userMatrix = lib.flatten (
    map (user: map (system: { inherit user system; }) supportedSystems) userNames
  );

  mkUser =
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
    );

  # ==========================================
  # 3. QUALITY CHECKS
  # HOME is set to TMPDIR so treefmt can write its cache database;
  # the Nix build sandbox points $HOME at /homeless-shelter by default.
  # ==========================================
  mkChecks =
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      format =
        pkgs.runCommand "treefmt-check"
          {
            nativeBuildInputs = with pkgs; [
              treefmt
              nixfmt
              deadnix
            ];
          }
          ''
            export HOME=$TMPDIR
            cp -r ${self}/. .
            chmod -R u+w .
            treefmt --check
            touch $out
          '';

      lint =
        pkgs.runCommand "statix-check"
          {
            nativeBuildInputs = [ pkgs.statix ];
          }
          ''
            cd ${self}
            statix check .
            touch $out
          '';
    };

in
{
  nixosConfigurations = builtins.listToAttrs (map mkNixosMachine nixosMachines);
  darwinConfigurations = builtins.listToAttrs (map mkDarwinMachine darwinMachines);
  homeConfigurations = builtins.listToAttrs (map mkUser userMatrix);
  checks = lib.genAttrs checkSystems mkChecks;
}
