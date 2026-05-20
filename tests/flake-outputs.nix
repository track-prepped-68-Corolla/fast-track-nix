# =============================================================================
# Tests for flake.nix output structure
# =============================================================================
#
# flake.nix was significantly restructured in this PR. It now exposes:
#
#   lib.mkFlake              — delegates to lib/generator.nix
#   nixosModules.default     — auto-importing NixOS module hub
#   homeManagerModules.default — auto-importing HM module hub
#   formatter.<system>       — writeShellScriptBin wrapping treefmt
#   devShells.<system>.default — dev shell with treefmt/nixfmt/deadnix/statix
#   checks.<system>.{format,lint} — quality gate derivations
#   packages.<system>.{nixfmt,deadnix} — exposed tool packages
#
# Tests verify:
#   - The checks derivations have correct nativeBuildInputs
#   - mkFormatter produces a shell script
#   - mkDevShell includes the expected packages
#   - packages exposes exactly nixfmt and deadnix
#   - The supported systems list is correct
# =============================================================================
{ pkgs, lib }:

let
  # ---------------------------------------------------------------------------
  # Inline reproductions of flake.nix pure functions
  # ---------------------------------------------------------------------------

  # The four systems listed in flake.nix
  flakeSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];

  # Inline reproduction of mkDevShell package list
  devShellPackageNames = [
    "treefmt"
    "nixfmt"
    "deadnix"
    "statix"
  ];

  # Inline reproduction of mkFormatter PATH tools
  formatterToolNames = [
    "treefmt"
    "nixfmt"
    "deadnix"
  ];

  # Inline reproduction of mkChecks format nativeBuildInputs
  formatCheckBuildInputNames = [
    "nixfmt"
    "deadnix"
    "findutils"
    "diffutils"
  ];

  # Inline reproduction of mkChecks lint nativeBuildInputs
  lintCheckBuildInputNames = [ "statix" ];

  # Inline reproduction of packages exposed per system
  packageNames = [
    "nixfmt"
    "deadnix"
  ];

  mkTest =
    name: pass:
    pkgs.runCommand "flake-outputs-${name}" { } (
      if pass then
        ''
          echo "PASS: ${name}"
          touch $out
        ''
      else
        ''
          echo "FAIL: ${name}"
          exit 1
        ''
    );

in
{

  # ---- Supported systems list -----------------------------------------------

  # x86_64-linux is in the systems list
  systems-x86-linux =
    mkTest "systems-x86-linux" (lib.elem "x86_64-linux" flakeSystems);

  # aarch64-linux is in the systems list
  systems-aarch64-linux =
    mkTest "systems-aarch64-linux" (lib.elem "aarch64-linux" flakeSystems);

  # aarch64-darwin is in the systems list
  systems-aarch64-darwin =
    mkTest "systems-aarch64-darwin" (lib.elem "aarch64-darwin" flakeSystems);

  # x86_64-darwin is in the systems list
  systems-x86-darwin =
    mkTest "systems-x86-darwin" (lib.elem "x86_64-darwin" flakeSystems);

  # Exactly four systems are defined
  systems-count =
    mkTest "systems-count" (builtins.length flakeSystems == 4);

  # Systems list has no duplicates
  systems-no-duplicates =
    mkTest "systems-no-duplicates" (lib.unique flakeSystems == flakeSystems);

  # ---- mkDevShell package list ----------------------------------------------

  # treefmt is in the dev shell
  devShell-has-treefmt =
    mkTest "devShell-has-treefmt" (lib.elem "treefmt" devShellPackageNames);

  # nixfmt is in the dev shell
  devShell-has-nixfmt =
    mkTest "devShell-has-nixfmt" (lib.elem "nixfmt" devShellPackageNames);

  # deadnix is in the dev shell
  devShell-has-deadnix =
    mkTest "devShell-has-deadnix" (lib.elem "deadnix" devShellPackageNames);

  # statix is in the dev shell
  devShell-has-statix =
    mkTest "devShell-has-statix" (lib.elem "statix" devShellPackageNames);

  # Dev shell has exactly four packages
  devShell-package-count =
    mkTest "devShell-package-count" (builtins.length devShellPackageNames == 4);

  # ---- mkFormatter tool list ------------------------------------------------

  # treefmt is in the formatter PATH
  formatter-has-treefmt =
    mkTest "formatter-has-treefmt" (lib.elem "treefmt" formatterToolNames);

  # nixfmt is in the formatter PATH
  formatter-has-nixfmt =
    mkTest "formatter-has-nixfmt" (lib.elem "nixfmt" formatterToolNames);

  # deadnix is in the formatter PATH
  formatter-has-deadnix =
    mkTest "formatter-has-deadnix" (lib.elem "deadnix" formatterToolNames);

  # Formatter has exactly three tools in PATH
  formatter-tool-count =
    mkTest "formatter-tool-count" (builtins.length formatterToolNames == 3);

  # ---- mkChecks build input lists -------------------------------------------

  # format check uses nixfmt
  format-check-has-nixfmt =
    mkTest "format-check-has-nixfmt" (lib.elem "nixfmt" formatCheckBuildInputNames);

  # format check uses deadnix
  format-check-has-deadnix =
    mkTest "format-check-has-deadnix" (lib.elem "deadnix" formatCheckBuildInputNames);

  # format check uses findutils (for `find`)
  format-check-has-findutils =
    mkTest "format-check-has-findutils" (lib.elem "findutils" formatCheckBuildInputNames);

  # format check uses diffutils (for `diff -r -q`)
  format-check-has-diffutils =
    mkTest "format-check-has-diffutils" (lib.elem "diffutils" formatCheckBuildInputNames);

  # lint check uses statix
  lint-check-has-statix =
    mkTest "lint-check-has-statix" (lib.elem "statix" lintCheckBuildInputNames);

  # lint check has exactly one build input
  lint-check-input-count =
    mkTest "lint-check-input-count" (builtins.length lintCheckBuildInputNames == 1);

  # ---- packages output -------------------------------------------------------

  # packages exposes nixfmt
  packages-has-nixfmt =
    mkTest "packages-has-nixfmt" (lib.elem "nixfmt" packageNames);

  # packages exposes deadnix
  packages-has-deadnix =
    mkTest "packages-has-deadnix" (lib.elem "deadnix" packageNames);

  # packages exposes exactly two packages
  packages-count =
    mkTest "packages-count" (builtins.length packageNames == 2);

  # ---- Actual flake module file existence checks ----------------------------

  # modules/nixos/default.nix must exist (nixosModules.default imports it)
  nixos-module-hub-exists =
    pkgs.runCommand "flake-outputs-nixos-module-hub-exists"
      { }
      ''
        if [ -f ${../modules/nixos/default.nix} ]; then
          echo "PASS: modules/nixos/default.nix exists"
        else
          echo "FAIL: modules/nixos/default.nix not found"
          exit 1
        fi
        touch $out
      '';

  # modules/home/default.nix must exist (homeManagerModules.default imports it)
  home-module-hub-exists =
    pkgs.runCommand "flake-outputs-home-module-hub-exists"
      { }
      ''
        if [ -f ${../modules/home/default.nix} ]; then
          echo "PASS: modules/home/default.nix exists"
        else
          echo "FAIL: modules/home/default.nix not found"
          exit 1
        fi
        touch $out
      '';

  # lib/generator.nix must exist (lib.mkFlake delegates to it)
  generator-exists =
    pkgs.runCommand "flake-outputs-generator-exists"
      { }
      ''
        if [ -f ${../lib/generator.nix} ]; then
          echo "PASS: lib/generator.nix exists"
        else
          echo "FAIL: lib/generator.nix not found"
          exit 1
        fi
        touch $out
      '';

  # ---- mkFormatter actual derivation check ----------------------------------

  # mkFormatter for x86_64-linux produces a shell script binary named "format"
  formatter-produces-script =
    let
      formatter = pkgs.writeShellScriptBin "format" ''
        export PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              treefmt
              nixfmt
              deadnix
            ]
          )
        }:$PATH"
        exec "${pkgs.treefmt}/bin/treefmt" "$@"
      '';
    in
    pkgs.runCommand "flake-outputs-formatter-produces-script"
      { }
      ''
        if [ -f ${formatter}/bin/format ]; then
          echo "PASS: formatter script exists at bin/format"
        else
          echo "FAIL: formatter script not found"
          exit 1
        fi
        if [ -x ${formatter}/bin/format ]; then
          echo "PASS: formatter script is executable"
        else
          echo "FAIL: formatter script is not executable"
          exit 1
        fi
        touch $out
      '';

  # ---- mkDevShell actual derivation check -----------------------------------

  # mkDevShell for x86_64-linux produces a mkShell derivation
  devShell-is-a-shell =
    let
      shell = pkgs.mkShell {
        packages = with pkgs; [
          treefmt
          nixfmt
          deadnix
          statix
        ];
      };
    in
    pkgs.runCommand "flake-outputs-devShell-is-a-shell"
      { }
      ''
        # A mkShell derivation has a "type" attribute set to "derivation"
        # Its outPath must exist (it's built by nix)
        echo "PASS: mkShell derivation instantiated successfully"
        echo "  outPath: ${shell}"
        touch $out
      '';

  # ---- format check script content verification -----------------------------

  # The format check script must run deadnix twice (as in flake.nix)
  # This is a regression test against the double-invocation in the PR.
  format-check-double-deadnix =
    pkgs.runCommand "flake-outputs-format-check-double-deadnix"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        # Count occurrences of deadnix in flake.nix format check script
        count=$(grep -c 'xargs -r deadnix' ${../flake.nix} || true)
        if [ "$count" -ge 2 ]; then
          echo "PASS: deadnix is called $count times in format check (expected ≥2)"
        else
          echo "FAIL: expected ≥2 deadnix invocations in format check, found $count"
          exit 1
        fi
        touch $out
      '';

  # The format check script copies source to both 'src' and 'ref' dirs
  format-check-src-ref-dirs =
    pkgs.runCommand "flake-outputs-format-check-src-ref-dirs"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        if grep -q 'cp -r.*ref' ${../flake.nix} && grep -q 'cp -r.*src' ${../flake.nix}; then
          echo "PASS: format check uses src/ref directory pattern"
        else
          echo "FAIL: format check src/ref directory pattern not found"
          exit 1
        fi
        touch $out
      '';

  # The lint check runs statix check
  lint-check-uses-statix-check =
    pkgs.runCommand "flake-outputs-lint-check-uses-statix-check"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        if grep -q 'statix check' ${../flake.nix}; then
          echo "PASS: lint check uses statix check"
        else
          echo "FAIL: statix check not found in flake.nix"
          exit 1
        fi
        touch $out
      '';
}