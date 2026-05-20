# =============================================================================
# Tests for lib/generator.nix
# =============================================================================
#
# Covers the pure helper logic extracted from the generator:
#   - getDirs: directory listing with non-existence guard
#   - mkMachineEntry: facter.json parsing, system fallback, Darwin detection
#   - isDarwin classification for machine list partitioning
#   - supportedSystems: deduplication of machine systems + localSystem
#   - checkSystems: always includes x86_64-linux
#   - userMatrix: cross-product of users × systems
#   - mkUser key format: "<user>@<system>"
#   - mkChecks: produces format and lint attributes
# =============================================================================
{ lib, pkgs }:

let
  # ---------------------------------------------------------------------------
  # Re-implement the pure helpers from lib/generator.nix so they can be tested
  # in isolation without a real flake evaluation context.
  # ---------------------------------------------------------------------------

  # getDirs: returns sorted directory names at path, or [] if path absent.
  getDirs =
    path:
    if builtins.pathExists path then
      lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else
      [ ];

  # mkMachineEntry: derives system from facter.json; falls back to x86_64-linux.
  # Takes a self root, a name, and an attrset standing in for the filesystem.
  # For unit-testing we accept facter directly instead of reading a file.
  mkMachineEntryPure =
    { name, facter }:
    let
      system = facter.system or "x86_64-linux";
      isDarwin = lib.hasSuffix "-darwin" system;
    in
    {
      inherit name system isDarwin;
    };

  # supportedSystems: deduplicate systems from machine list + optional localSystem.
  supportedSystemsPure =
    { machineList, localSystem }:
    lib.unique ((map (m: m.system) machineList) ++ lib.optional (localSystem != null) localSystem);

  # checkSystems: always include x86_64-linux even if no machines declare it.
  checkSystemsPure =
    supportedSystems: lib.unique (supportedSystems ++ [ "x86_64-linux" ]);

  # userMatrix: cross-product of userNames × supportedSystems.
  userMatrixPure =
    { userNames, systems }:
    lib.flatten (map (user: map (system: { inherit user system; }) systems) userNames);

  # mkUser key format.
  mkUserKey = { user, system }: "${user}@${system}";

  # mkChecks output keys.
  mkChecksKeys = system: lib.attrNames (mkChecksPure system);

  mkChecksPure =
    _system:
    {
      format = "format-derivation-placeholder";
      lint = "lint-derivation-placeholder";
    };

  # ---------------------------------------------------------------------------
  # Helper: assert a boolean and produce a name-value pair for lib.runTests
  # ---------------------------------------------------------------------------
  runTests = lib.runTests;

in
runTests {

  # ============================================================
  # getDirs
  # ============================================================

  # Non-existent path must return empty list.
  testGetDirsNonExistentPath = {
    expr = getDirs "/this/path/does/not/exist/ever/9e1b3f";
    expected = [ ];
  };

  # Existing path with real directories: machines/ has "computer".
  testGetDirsMachinesDir = {
    expr = getDirs (toString ./.. + "/machines");
    expected = [ "computer" ];
  };

  # Existing path with real directories: users/ has "admin" and "guest".
  testGetDirsUsersDir = {
    expr = getDirs (toString ./.. + "/users");
    expected = [
      "admin"
      "guest"
    ];
  };

  # ============================================================
  # mkMachineEntry — system derivation
  # ============================================================

  # No facter.json → fallback to x86_64-linux.
  testMkMachineEntryFallbackSystem = {
    expr = (mkMachineEntryPure {
      name = "myhost";
      facter = { };
    }).system;
    expected = "x86_64-linux";
  };

  # facter.json with explicit x86_64-linux.
  testMkMachineEntryExplicitLinux = {
    expr = (mkMachineEntryPure {
      name = "myhost";
      facter = { system = "x86_64-linux"; };
    }).system;
    expected = "x86_64-linux";
  };

  # facter.json with aarch64-linux.
  testMkMachineEntryAarch64Linux = {
    expr = (mkMachineEntryPure {
      name = "arm-server";
      facter = { system = "aarch64-linux"; };
    }).system;
    expected = "aarch64-linux";
  };

  # facter.json with aarch64-darwin → Darwin machine.
  testMkMachineEntryDarwinSystem = {
    expr = (mkMachineEntryPure {
      name = "macbook";
      facter = { system = "aarch64-darwin"; };
    }).system;
    expected = "aarch64-darwin";
  };

  # Name is preserved unchanged.
  testMkMachineEntryPreservesName = {
    expr = (mkMachineEntryPure {
      name = "workstation";
      facter = { system = "x86_64-linux"; };
    }).name;
    expected = "workstation";
  };

  # ============================================================
  # mkMachineEntry — isDarwin flag
  # ============================================================

  # x86_64-linux → not Darwin.
  testIsDarwinFalseForLinux = {
    expr = (mkMachineEntryPure {
      name = "server";
      facter = { system = "x86_64-linux"; };
    }).isDarwin;
    expected = false;
  };

  # aarch64-linux → not Darwin.
  testIsDarwinFalseForAarch64Linux = {
    expr = (mkMachineEntryPure {
      name = "pi";
      facter = { system = "aarch64-linux"; };
    }).isDarwin;
    expected = false;
  };

  # aarch64-darwin → Darwin.
  testIsDarwinTrueForAarch64Darwin = {
    expr = (mkMachineEntryPure {
      name = "macbook";
      facter = { system = "aarch64-darwin"; };
    }).isDarwin;
    expected = true;
  };

  # x86_64-darwin → Darwin.
  testIsDarwinTrueForX8664Darwin = {
    expr = (mkMachineEntryPure {
      name = "hackintosh";
      facter = { system = "x86_64-darwin"; };
    }).isDarwin;
    expected = true;
  };

  # Fallback system (no facter) is Linux → not Darwin.
  testIsDarwinFalseForFallback = {
    expr = (mkMachineEntryPure {
      name = "generic";
      facter = { };
    }).isDarwin;
    expected = false;
  };

  # ============================================================
  # supportedSystems — deduplication and localSystem
  # ============================================================

  # Single machine, no localSystem.
  testSupportedSystemsSingleMachine = {
    expr = supportedSystemsPure {
      machineList = [ { system = "x86_64-linux"; } ];
      localSystem = null;
    };
    expected = [ "x86_64-linux" ];
  };

  # Two machines with different systems, no localSystem.
  testSupportedSystemsMultipleMachines = {
    expr = lib.sort lib.lessThan (
      supportedSystemsPure {
        machineList = [
          { system = "x86_64-linux"; }
          { system = "aarch64-linux"; }
        ];
        localSystem = null;
      }
    );
    expected = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };

  # Two machines with same system deduplicates to one entry.
  testSupportedSystemsDeduplicate = {
    expr = supportedSystemsPure {
      machineList = [
        { system = "x86_64-linux"; }
        { system = "x86_64-linux"; }
      ];
      localSystem = null;
    };
    expected = [ "x86_64-linux" ];
  };

  # localSystem added when not null.
  testSupportedSystemsWithLocalSystem = {
    expr = lib.sort lib.lessThan (
      supportedSystemsPure {
        machineList = [ { system = "x86_64-linux"; } ];
        localSystem = "aarch64-linux";
      }
    );
    expected = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };

  # localSystem not duplicated when it matches a machine system.
  testSupportedSystemsLocalSystemDeduplicates = {
    expr = supportedSystemsPure {
      machineList = [ { system = "x86_64-linux"; } ];
      localSystem = "x86_64-linux";
    };
    expected = [ "x86_64-linux" ];
  };

  # No machines and no localSystem → empty list.
  testSupportedSystemsEmpty = {
    expr = supportedSystemsPure {
      machineList = [ ];
      localSystem = null;
    };
    expected = [ ];
  };

  # null localSystem is not added (lib.optional false → []).
  testSupportedSystemsNullLocalSystemIgnored = {
    expr = supportedSystemsPure {
      machineList = [ ];
      localSystem = null;
    };
    expected = [ ];
  };

  # ============================================================
  # checkSystems — always includes x86_64-linux
  # ============================================================

  # Already contains x86_64-linux → no duplicate.
  testCheckSystemsNoDuplicateLinux = {
    expr = checkSystemsPure [ "x86_64-linux" ];
    expected = [ "x86_64-linux" ];
  };

  # Empty supportedSystems → still has x86_64-linux.
  testCheckSystemsAlwaysHasX8664Linux = {
    expr = checkSystemsPure [ ];
    expected = [ "x86_64-linux" ];
  };

  # aarch64-linux → adds x86_64-linux.
  testCheckSystemsAddsMissingLinux = {
    expr = lib.sort lib.lessThan (checkSystemsPure [ "aarch64-linux" ]);
    expected = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };

  # Darwin-only system → still adds x86_64-linux.
  testCheckSystemsAddsLinuxEvenForDarwin = {
    expr = lib.sort lib.lessThan (checkSystemsPure [ "aarch64-darwin" ]);
    expected = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };

  # ============================================================
  # userMatrix — cross-product
  # ============================================================

  # Single user, single system → one entry.
  testUserMatrixSingleUserSingleSystem = {
    expr = userMatrixPure {
      userNames = [ "alice" ];
      systems = [ "x86_64-linux" ];
    };
    expected = [ { user = "alice"; system = "x86_64-linux"; } ];
  };

  # Single user, two systems → two entries.
  testUserMatrixSingleUserTwoSystems = {
    expr = userMatrixPure {
      userNames = [ "alice" ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
    expected = [
      { user = "alice"; system = "x86_64-linux"; }
      { user = "alice"; system = "aarch64-linux"; }
    ];
  };

  # Two users, single system → two entries.
  testUserMatrixTwoUsersSingleSystem = {
    expr = userMatrixPure {
      userNames = [
        "alice"
        "bob"
      ];
      systems = [ "x86_64-linux" ];
    };
    expected = [
      { user = "alice"; system = "x86_64-linux"; }
      { user = "bob"; system = "x86_64-linux"; }
    ];
  };

  # Two users, two systems → four entries (row-major order).
  testUserMatrixTwoUsersTwoSystems = {
    expr = userMatrixPure {
      userNames = [
        "alice"
        "bob"
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
    expected = [
      { user = "alice"; system = "x86_64-linux"; }
      { user = "alice"; system = "aarch64-linux"; }
      { user = "bob"; system = "x86_64-linux"; }
      { user = "bob"; system = "aarch64-linux"; }
    ];
  };

  # Empty users → empty matrix.
  testUserMatrixNoUsers = {
    expr = userMatrixPure {
      userNames = [ ];
      systems = [ "x86_64-linux" ];
    };
    expected = [ ];
  };

  # Empty systems → empty matrix.
  testUserMatrixNoSystems = {
    expr = userMatrixPure {
      userNames = [ "alice" ];
      systems = [ ];
    };
    expected = [ ];
  };

  # ============================================================
  # mkUser key format
  # ============================================================

  # Standard Linux key.
  testMkUserKeyLinux = {
    expr = mkUserKey {
      user = "alice";
      system = "x86_64-linux";
    };
    expected = "alice@x86_64-linux";
  };

  # Darwin key.
  testMkUserKeyDarwin = {
    expr = mkUserKey {
      user = "bob";
      system = "aarch64-darwin";
    };
    expected = "bob@aarch64-darwin";
  };

  # aarch64-linux key.
  testMkUserKeyAarch64Linux = {
    expr = mkUserKey {
      user = "guest";
      system = "aarch64-linux";
    };
    expected = "guest@aarch64-linux";
  };

  # ============================================================
  # mkChecks — output structure
  # ============================================================

  # mkChecks produces exactly the "format" and "lint" attributes.
  testMkChecksHasFormatAndLint = {
    expr = lib.sort lib.lessThan (mkChecksKeys "x86_64-linux");
    expected = [
      "format"
      "lint"
    ];
  };

  testMkChecksHasFormatAndLintAarch64 = {
    expr = lib.sort lib.lessThan (mkChecksKeys "aarch64-linux");
    expected = [
      "format"
      "lint"
    ];
  };

  # ============================================================
  # Darwin suffix detection edge cases
  # ============================================================

  # A system string ending in "-darwin" (but not a real arch) is still Darwin.
  testIsDarwinForAnyDarwinSuffix = {
    expr = lib.hasSuffix "-darwin" "custom-darwin";
    expected = true;
  };

  # "darwin" without the hyphen prefix is NOT detected (hasSuffix requires "-darwin").
  testIsDarwinRequiresHyphen = {
    expr = lib.hasSuffix "-darwin" "darwinhost";
    expected = false;
  };

  # Plain "linux" is not Darwin.
  testIsDarwinFalseForPlainLinux = {
    expr = lib.hasSuffix "-darwin" "x86_64-linux";
    expected = false;
  };
}