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
# PROFILE DISCOVERY
#   Scans inputs.self/users/<username>/profiles/<name>/ for directories.
#   Every non-empty combination of a user's profiles gets its own
#   homeConfiguration, named "<user>+<profile1>+<profile2>...@<system>"
#   (profile names always alphabetical in the combo name), layered on top
#   of the user's base config. "<user>@<system>" with no profiles still
#   works unchanged.
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
  # 1b. IMAGE MACHINE DETECTION
  # ==========================================
  # machines/<name>/var/format — presence of this file marks the machine as an
  # ISO image build rather than a deployable system.  The generator emits
  # packages.<system>.<name> for image machines and excludes them from
  # nixosConfigurations so they don't fail filesystem/bootloader assertions.
  isImageMachine = machine: builtins.pathExists (machine.path + "/var/format");

  imageMachines = builtins.filter isImageMachine nixosMachines;
  # Image machines are not deployable NixOS systems — exclude them from
  # nixosConfigurations so they don't fail the filesystem/bootloader assertions.
  deployableMachines = builtins.filter (m: !isImageMachine m) nixosMachines;

  mkImagePackage =
    machine:
    let
      nixos = lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          # Live-system base: squashfs rootfs, GRUB/EFI bootloader, autologin
          # root — no NixOS installer layer.  The machine config supplies the
          # rest (ft.liveIso, extra tools, SSH keys, etc.).
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"
          inputs.Disko.nixosModules.disko
          inputs.microvm.nixosModules.host
          ../modules/nixos
          machine.path
          { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
        ];
      };
    in
    nixos.config.system.build.isoImage;

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

  # ==========================================
  # 2b. PROFILE DISCOVERY
  # ==========================================
  # users/<user>/profiles/<name>/ — optional extra Home Manager modules layered
  # on top of the base user config. Every non-empty combination of a user's
  # profiles is generated as its own homeConfiguration, named
  # "<user>+<profile1>+<profile2>...@<system>". getDirs returns names in
  # alphabetical order and the powerset below preserves relative order, so
  # combo names are always in alphabetical order regardless of how the
  # profiles/ directory was populated.
  profilesOf = user: getDirs (usersDir + "/${user}/profiles");

  powerset = list: lib.foldl' (acc: x: acc ++ map (s: s ++ [ x ]) acc) [ [ ] ] list;

  profileCombos = user: builtins.filter (combo: combo != [ ]) (powerset (profilesOf user));

  userProfileMatrix = lib.flatten (
    map (
      user:
      map (combo: map (system: { inherit user combo system; }) supportedSystems) (profileCombos user)
    ) userNames
  );

  mkHomeConfiguration =
    {
      user,
      system,
      profileModules ? [ ],
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        inherit inputs;
        ftUserPath = usersDir + "/${user}";
      };
      modules = [
        ../modules/home
        (usersDir + "/${user}")
      ]
      ++ profileModules;
    };
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
      ) deployableMachines
    );

    darwinConfigurations = builtins.listToAttrs (
      map (
        machine:
        assert lib.assertMsg (
          darwin != null
        ) "The 'darwin' input is missing, but a macOS machine (${machine.name}) was discovered!";
        lib.nameValuePair machine.name (
          lib.warn
            "ft-home: Darwin module injection is not yet implemented — ft.* options are unavailable for machine '${machine.name}'. See modules/darwin/default.nix."
            (
              darwin.lib.darwinSystem {
                specialArgs = { inherit inputs; };
                modules = [
                  ../modules/darwin
                  machine.path
                  { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
                ];
              }
            )
        )
      ) darwinMachines
    );

    homeConfigurations = builtins.listToAttrs (
      map (
        { user, system }:
        lib.nameValuePair "${user}@${system}" (mkHomeConfiguration {
          inherit user system;
        })
      ) userMatrix
      ++ map (
        {
          user,
          combo,
          system,
        }:
        lib.nameValuePair "${user}+${lib.concatStringsSep "+" combo}@${system}" (mkHomeConfiguration {
          inherit user system;
          profileModules = map (profile: usersDir + "/${user}/profiles/${profile}") combo;
        })
      ) userProfileMatrix
    );

    # Machines with a var/format file are built as ISO image packages.
    # packages.<system>.<name> is the bootable .iso derivation.
    packages = lib.foldr (
      machine: acc:
      lib.recursiveUpdate acc { ${machine.system}.${machine.name} = mkImagePackage machine; }
    ) { } imageMachines;
  };
}
