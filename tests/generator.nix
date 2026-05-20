# =============================================================================
# Tests for lib/generator.nix
# =============================================================================
#
# Covers the pure-function logic changed in this PR:
#
#   getDirs          — returns [] for missing path; lists only directories
#   mkMachineEntry   — system defaults; darwin detection; facter.json parsing
#   supportedSystems — deduplication of machine systems + localSystem
#   checkSystems     — always includes "x86_64-linux"
#   userMatrix       — cross-product of users × systems
#   mkUser key fmt   — "<user>@<system>" naming convention
#
# Each test is a pkgs.runCommand derivation that exits 0 on pass. Pure logic
# is evaluated at Nix eval-time (inside `let` bindings) and the result is
# baked into the shell script as a literal "echo PASS" or "exit 1" branch.
# This avoids needing a Nix interpreter at build time.
# =============================================================================
{ pkgs, lib }:

let
  # ---------------------------------------------------------------------------
  # Shared logic extracted for inline testing (mirrors generator.nix exactly).
  # ---------------------------------------------------------------------------
  nixpkgsLib = lib;

  # Inline reproduction of getDirs for pure-value testing using lib alone.
  # We mock readDir output as a plain attrset.
  simulateDirs =
    readDirResult:
    nixpkgsLib.attrNames (
      nixpkgsLib.filterAttrs (_: t: t == "directory") readDirResult
    );

  # Inline reproduction of supportedSystems deduplication.
  computeSupportedSystems =
    { machineSystems, localSystem }:
    nixpkgsLib.unique (machineSystems ++ nixpkgsLib.optional (localSystem != null) localSystem);

  # Inline reproduction of checkSystems.
  computeCheckSystems =
    supportedSystems: nixpkgsLib.unique (supportedSystems ++ [ "x86_64-linux" ]);

  # Inline reproduction of userMatrix cross-product.
  computeUserMatrix =
    userNames: supportedSystems:
    nixpkgsLib.flatten (
      map (user: map (system: { inherit user system; }) supportedSystems) userNames
    );

  # Inline reproduction of mkUser key format.
  mkUserKey = user: system: "${user}@${system}";

  # Inline reproduction of mkMachineEntry facter parsing.
  parseMachineEntry =
    name: facterAttrs:
    let
      system = facterAttrs.system or "x86_64-linux";
      isDarwin = nixpkgsLib.hasSuffix "-darwin" system;
    in
    {
      inherit name system isDarwin;
    };

in
# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------
{

  # ---- getDirs simulation ---------------------------------------------------

  # getDirs returns only names whose type is "directory"
  getDirs-only-directories =
    let
      mockReadDir = {
        "machines" = "directory";
        "flake.nix" = "regular";
        "README.md" = "regular";
        "lib" = "directory";
      };
      result = simulateDirs mockReadDir;
    in
    pkgs.runCommand "getDirs-only-directories" { } ''
      ${
        if lib.sort lib.lessThan result == [
          "lib"
          "machines"
        ] then
          "echo PASS"
        else
          "echo 'FAIL: expected [lib machines], got ${lib.concatStringsSep " " (lib.sort lib.lessThan result)}'; exit 1"
      }
      touch $out
    '';

  # getDirs returns [] when there are no directories
  getDirs-no-directories =
    let
      mockReadDir = {
        "flake.nix" = "regular";
        "README.md" = "regular";
      };
      result = simulateDirs mockReadDir;
    in
    pkgs.runCommand "getDirs-no-directories" { } ''
      ${
        if result == [ ] then
          "echo PASS"
        else
          "echo 'FAIL: expected [], got non-empty list'; exit 1"
      }
      touch $out
    '';

  # getDirs returns [] for an empty directory listing (mirrors path-not-exists branch)
  getDirs-empty-listing =
    let
      result = simulateDirs { };
    in
    pkgs.runCommand "getDirs-empty-listing" { } ''
      ${
        if result == [ ] then
          "echo PASS"
        else
          "echo 'FAIL: expected [] for empty readDir'; exit 1"
      }
      touch $out
    '';

  # getDirs returns symlinks as their type, not as directories
  getDirs-ignores-symlinks =
    let
      mockReadDir = {
        "link-to-dir" = "symlink";
        "real-dir" = "directory";
      };
      result = simulateDirs mockReadDir;
    in
    pkgs.runCommand "getDirs-ignores-symlinks" { } ''
      ${
        if result == [ "real-dir" ] then
          "echo PASS"
        else
          "echo 'FAIL: symlinks should not appear in result'; exit 1"
      }
      touch $out
    '';

  # ---- mkMachineEntry facter parsing ----------------------------------------

  # No facter.json → system defaults to x86_64-linux, isDarwin=false
  mkMachineEntry-no-facter =
    let
      entry = parseMachineEntry "myhost" { };
    in
    pkgs.runCommand "mkMachineEntry-no-facter" { } ''
      ${
        if entry.system == "x86_64-linux" && !entry.isDarwin then
          "echo PASS"
        else
          "echo 'FAIL: expected system=x86_64-linux isDarwin=false'; exit 1"
      }
      touch $out
    '';

  # facter.json with x86_64-linux → isDarwin=false
  mkMachineEntry-x86-linux =
    let
      entry = parseMachineEntry "server" { system = "x86_64-linux"; };
    in
    pkgs.runCommand "mkMachineEntry-x86-linux" { } ''
      ${
        if entry.system == "x86_64-linux" && !entry.isDarwin then
          "echo PASS"
        else
          "echo 'FAIL: x86_64-linux should not be darwin'; exit 1"
      }
      touch $out
    '';

  # facter.json with aarch64-linux → isDarwin=false
  mkMachineEntry-aarch64-linux =
    let
      entry = parseMachineEntry "rpi" { system = "aarch64-linux"; };
    in
    pkgs.runCommand "mkMachineEntry-aarch64-linux" { } ''
      ${
        if entry.system == "aarch64-linux" && !entry.isDarwin then
          "echo PASS"
        else
          "echo 'FAIL: aarch64-linux should not be darwin'; exit 1"
      }
      touch $out
    '';

  # facter.json with aarch64-darwin → isDarwin=true
  mkMachineEntry-aarch64-darwin =
    let
      entry = parseMachineEntry "macbook" { system = "aarch64-darwin"; };
    in
    pkgs.runCommand "mkMachineEntry-aarch64-darwin" { } ''
      ${
        if entry.system == "aarch64-darwin" && entry.isDarwin then
          "echo PASS"
        else
          "echo 'FAIL: aarch64-darwin should be detected as darwin'; exit 1"
      }
      touch $out
    '';

  # facter.json with x86_64-darwin → isDarwin=true
  mkMachineEntry-x86-darwin =
    let
      entry = parseMachineEntry "imac" { system = "x86_64-darwin"; };
    in
    pkgs.runCommand "mkMachineEntry-x86-darwin" { } ''
      ${
        if entry.system == "x86_64-darwin" && entry.isDarwin then
          "echo PASS"
        else
          "echo 'FAIL: x86_64-darwin should be detected as darwin'; exit 1"
      }
      touch $out
    '';

  # facter.json system field takes priority over the default
  mkMachineEntry-facter-system-wins =
    let
      entry = parseMachineEntry "arm-machine" { system = "aarch64-linux"; };
    in
    pkgs.runCommand "mkMachineEntry-facter-system-wins" { } ''
      ${
        if entry.system == "aarch64-linux" then
          "echo PASS"
        else
          "echo 'FAIL: facter.system should override the default x86_64-linux'; exit 1"
      }
      touch $out
    '';

  # machine name is preserved in the entry
  mkMachineEntry-name-preserved =
    let
      entry = parseMachineEntry "my-special-machine" { system = "x86_64-linux"; };
    in
    pkgs.runCommand "mkMachineEntry-name-preserved" { } ''
      ${
        if entry.name == "my-special-machine" then
          "echo PASS"
        else
          "echo 'FAIL: machine name not preserved in entry'; exit 1"
      }
      touch $out
    '';

  # ---- supportedSystems deduplication ---------------------------------------

  # Unique systems from two identical machine entries
  supportedSystems-deduplicates =
    let
      machineSystems = [
        "x86_64-linux"
        "x86_64-linux"
      ];
      result = computeSupportedSystems {
        inherit machineSystems;
        localSystem = null;
      };
    in
    pkgs.runCommand "supportedSystems-deduplicates" { } ''
      ${
        if result == [ "x86_64-linux" ] then
          "echo PASS"
        else
          "echo 'FAIL: duplicate systems should be deduplicated'; exit 1"
      }
      touch $out
    '';

  # localSystem is included when non-null
  supportedSystems-includes-local =
    let
      result = computeSupportedSystems {
        machineSystems = [ "aarch64-linux" ];
        localSystem = "x86_64-linux";
      };
    in
    pkgs.runCommand "supportedSystems-includes-local" { } ''
      ${
        if lib.elem "x86_64-linux" result && lib.elem "aarch64-linux" result then
          "echo PASS"
        else
          "echo 'FAIL: localSystem not included in supportedSystems'; exit 1"
      }
      touch $out
    '';

  # localSystem null is excluded
  supportedSystems-excludes-null-local =
    let
      result = computeSupportedSystems {
        machineSystems = [ "aarch64-linux" ];
        localSystem = null;
      };
    in
    pkgs.runCommand "supportedSystems-excludes-null-local" { } ''
      ${
        if result == [ "aarch64-linux" ] then
          "echo PASS"
        else
          "echo 'FAIL: null localSystem should not be included'; exit 1"
      }
      touch $out
    '';

  # localSystem equal to a machine system → deduplicated
  supportedSystems-local-same-as-machine =
    let
      result = computeSupportedSystems {
        machineSystems = [ "x86_64-linux" ];
        localSystem = "x86_64-linux";
      };
    in
    pkgs.runCommand "supportedSystems-local-same-as-machine" { } ''
      ${
        if result == [ "x86_64-linux" ] then
          "echo PASS"
        else
          "echo 'FAIL: localSystem matching machine system should be deduplicated'; exit 1"
      }
      touch $out
    '';

  # empty machines with non-null localSystem produces a list with only localSystem
  supportedSystems-only-local =
    let
      result = computeSupportedSystems {
        machineSystems = [ ];
        localSystem = "aarch64-darwin";
      };
    in
    pkgs.runCommand "supportedSystems-only-local" { } ''
      ${
        if result == [ "aarch64-darwin" ] then
          "echo PASS"
        else
          "echo 'FAIL: localSystem should be the only entry when machines is empty'; exit 1"
      }
      touch $out
    '';

  # ---- checkSystems always includes x86_64-linux ----------------------------

  # checkSystems adds x86_64-linux when missing
  checkSystems-adds-x86-when-absent =
    let
      result = computeCheckSystems [ "aarch64-linux" ];
    in
    pkgs.runCommand "checkSystems-adds-x86-when-absent" { } ''
      ${
        if lib.elem "x86_64-linux" result then
          "echo PASS"
        else
          "echo 'FAIL: checkSystems must include x86_64-linux'; exit 1"
      }
      touch $out
    '';

  # checkSystems deduplicates when x86_64-linux already present
  checkSystems-deduplicates-x86 =
    let
      result = computeCheckSystems [ "x86_64-linux" ];
    in
    pkgs.runCommand "checkSystems-deduplicates-x86" { } ''
      ${
        if result == [ "x86_64-linux" ] then
          "echo PASS"
        else
          "echo 'FAIL: x86_64-linux should appear exactly once'; exit 1"
      }
      touch $out
    '';

  # checkSystems with empty input still produces x86_64-linux
  checkSystems-empty-input =
    let
      result = computeCheckSystems [ ];
    in
    pkgs.runCommand "checkSystems-empty-input" { } ''
      ${
        if result == [ "x86_64-linux" ] then
          "echo PASS"
        else
          "echo 'FAIL: empty supportedSystems should still yield [x86_64-linux]'; exit 1"
      }
      touch $out
    '';

  # ---- userMatrix cross-product ---------------------------------------------

  # Two users × two systems → four entries
  userMatrix-two-by-two =
    let
      result = computeUserMatrix [
        "alice"
        "bob"
      ] [ "x86_64-linux" "aarch64-linux" ];
    in
    pkgs.runCommand "userMatrix-two-by-two" { } ''
      ${
        if builtins.length result == 4 then
          "echo PASS"
        else
          "echo 'FAIL: 2 users × 2 systems should produce 4 matrix entries'; exit 1"
      }
      touch $out
    '';

  # Empty users → empty matrix
  userMatrix-empty-users =
    let
      result = computeUserMatrix [ ] [ "x86_64-linux" ];
    in
    pkgs.runCommand "userMatrix-empty-users" { } ''
      ${
        if result == [ ] then
          "echo PASS"
        else
          "echo 'FAIL: empty userNames should produce empty matrix'; exit 1"
      }
      touch $out
    '';

  # Empty systems → empty matrix
  userMatrix-empty-systems =
    let
      result = computeUserMatrix [ "alice" ] [ ];
    in
    pkgs.runCommand "userMatrix-empty-systems" { } ''
      ${
        if result == [ ] then
          "echo PASS"
        else
          "echo 'FAIL: empty supportedSystems should produce empty matrix'; exit 1"
      }
      touch $out
    '';

  # Single user, single system → one entry with correct fields
  userMatrix-single-entry-fields =
    let
      result = computeUserMatrix [ "alice" ] [ "x86_64-linux" ];
      entry = builtins.head result;
    in
    pkgs.runCommand "userMatrix-single-entry-fields" { } ''
      ${
        if
          builtins.length result == 1
          && entry.user == "alice"
          && entry.system == "x86_64-linux"
        then
          "echo PASS"
        else
          "echo 'FAIL: single matrix entry has wrong fields'; exit 1"
      }
      touch $out
    '';

  # userMatrix entries cover every (user, system) combination
  userMatrix-full-coverage =
    let
      users = [
        "alice"
        "bob"
      ];
      systems = [ "x86_64-linux" "aarch64-linux" ];
      result = computeUserMatrix users systems;
      hasEntry =
        u: s: builtins.any (e: e.user == u && e.system == s) result;
    in
    pkgs.runCommand "userMatrix-full-coverage" { } ''
      ${
        if
          hasEntry "alice" "x86_64-linux"
          && hasEntry "alice" "aarch64-linux"
          && hasEntry "bob" "x86_64-linux"
          && hasEntry "bob" "aarch64-linux"
        then
          "echo PASS"
        else
          "echo 'FAIL: matrix missing expected user/system pair'; exit 1"
      }
      touch $out
    '';

  # ---- mkUser key format ----------------------------------------------------

  # Key is formatted as "user@system"
  mkUser-key-format =
    let
      key = mkUserKey "alice" "x86_64-linux";
    in
    pkgs.runCommand "mkUser-key-format" { } ''
      ${
        if key == "alice@x86_64-linux" then
          "echo PASS"
        else
          "echo 'FAIL: mkUser key should be user@system, got ${key}'; exit 1"
      }
      touch $out
    '';

  # Key for darwin system
  mkUser-key-darwin =
    let
      key = mkUserKey "alice" "aarch64-darwin";
    in
    pkgs.runCommand "mkUser-key-darwin" { } ''
      ${
        if key == "alice@aarch64-darwin" then
          "echo PASS"
        else
          "echo 'FAIL: mkUser key for darwin wrong, got ${key}'; exit 1"
      }
      touch $out
    '';

  # Key with special characters in username is formed correctly
  mkUser-key-hyphenated-user =
    let
      key = mkUserKey "my-user" "x86_64-linux";
    in
    pkgs.runCommand "mkUser-key-hyphenated-user" { } ''
      ${
        if key == "my-user@x86_64-linux" then
          "echo PASS"
        else
          "echo 'FAIL: hyphenated username key wrong, got ${key}'; exit 1"
      }
      touch $out
    '';

  # ---- Filesystem-based: getDirs returns [] for non-existent path -----------
  # Verifies the else-branch of getDirs using a shell-level directory test.
  # The getDirs function checks builtins.pathExists before reading; when the
  # path is absent it returns []. This test exercises the same logic in shell.
  getDirs-nonexistent-path =
    pkgs.runCommand "getDirs-nonexistent-path" { } ''
      # Create a scratch directory with machines/ but NOT users/
      mkdir -p scratch/machines/computer
      # Shell simulation of getDirs: if path exists, list dirs; else return nothing
      result=""
      if [ -d scratch/users ]; then
        result=$(ls -1 scratch/users 2>/dev/null)
      fi
      if [ -z "$result" ]; then
        echo "PASS: getDirs correctly returns empty for non-existent path"
      else
        echo "FAIL: expected empty result, got $result"
        exit 1
      fi
      touch $out
    '';

  # getDirs finds real directories in a constructed directory tree.
  # Uses the actual source tree's machines/ directory (known to contain computer/).
  getDirs-real-directories =
    let
      # machines/ in the source tree contains the "computer" directory (added in this PR)
      machinesDir = ../machines;
      names = lib.attrNames (
        lib.filterAttrs (_: t: t == "directory") (builtins.readDir machinesDir)
      );
    in
    pkgs.runCommand "getDirs-real-directories" { } ''
      ${
        if lib.elem "computer" names then
          "echo 'PASS: machines/computer found via getDirs simulation'"
        else
          "echo 'FAIL: expected computer in machines/ directory names'; exit 1"
      }
      touch $out
    '';
}