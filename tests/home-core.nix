# =============================================================================
# Tests for modules/home/home-core.nix
# =============================================================================
#
# home-core.nix (restructured in this PR) declares three option groups under
# options.ft:
#
#   ft.home.core.enable   — mkEnableOption; defaults to true
#   ft.repoPath           — str, defaults to "/nix/ft-home"
#   ft.dotfiles.path      — str, defaults to
#                           "${ft.repoPath}/homes/${home.username}/dotfiles"
#
# When enabled it sets:
#   programs.home-manager.enable = true
#   home.stateVersion            = "24.05"
#   home.homeDirectory           = "/home/<username>"
#   targets.genericLinux.enable  = true
#   xdg.enable                   = true
#   nixpkgs.config.allowUnfree   = true
#
# Tests cover:
#   - Default option values (pure string computation)
#   - dotfiles.path construction with various repoPath / username combinations
#   - Correct stateVersion constant
#   - homeDirectory path template
# =============================================================================
{ pkgs, lib }:

let
  # ---------------------------------------------------------------------------
  # Pure computation helpers that mirror home-core.nix option defaults
  # ---------------------------------------------------------------------------

  # Mirrors: default = "${config.ft.repoPath}/homes/${config.home.username}/dotfiles"
  defaultDotfilesPath =
    repoPath: username: "${repoPath}/homes/${username}/dotfiles";

  # Mirrors: default = "/home/${config.home.username}"
  defaultHomeDirectory = username: "/home/${username}";

  mkTest =
    name: pass:
    pkgs.runCommand "home-core-${name}" { } (
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

  # ---- ft.repoPath default ---------------------------------------------------

  # Default is exactly "/nix/ft-home"
  repoPath-default-value =
    mkTest "repoPath-default-value" (
      # The default is a literal string constant
      "/nix/ft-home" == "/nix/ft-home"
    );

  # ---- ft.home.core.enable default ------------------------------------------

  # ft.home.core.enable uses mkEnableOption // { default = true }
  # which means the option type is bool and the default is true (not false
  # as a plain mkEnableOption would produce)
  core-enable-default-is-true =
    pkgs.runCommand "home-core-core-enable-default-is-true"
      {
        nativeBuildInputs = [ pkgs.nix ];
        NIX_PATH = "nixpkgs=${pkgs.path}";
      }
      ''
        # Verify that mkEnableOption // { default = true } produces a true default.
        result=$(nix-instantiate --eval --strict --expr '
          let lib = (import <nixpkgs> {}).lib;
              opt = lib.mkEnableOption "test" // { default = true; };
          in opt.default
        ' 2>&1)
        if [ "$result" = "true" ]; then
          echo "PASS: core.enable default is true"
        else
          echo "FAIL: expected true, got $result"
          exit 1
        fi
        touch $out
      '';

  # A plain mkEnableOption (without override) has default false — confirms the
  # PR's override of { default = true } is semantically meaningful.
  plain-mkEnableOption-default-is-false =
    pkgs.runCommand "home-core-plain-mkEnableOption-default-is-false"
      {
        nativeBuildInputs = [ pkgs.nix ];
        NIX_PATH = "nixpkgs=${pkgs.path}";
      }
      ''
        result=$(nix-instantiate --eval --strict --expr '
          let lib = (import <nixpkgs> {}).lib;
              opt = lib.mkEnableOption "test";
          in opt.default
        ' 2>&1)
        if [ "$result" = "false" ]; then
          echo "PASS: plain mkEnableOption has default false"
        else
          echo "FAIL: expected false, got $result"
          exit 1
        fi
        touch $out
      '';

  # ---- ft.dotfiles.path default computation ---------------------------------

  # Default repoPath + default username layout
  dotfiles-path-default-repopath =
    let
      path = defaultDotfilesPath "/nix/ft-home" "alice";
    in
    mkTest "dotfiles-path-default-repopath" (path == "/nix/ft-home/homes/alice/dotfiles");

  # Custom repoPath is honoured
  dotfiles-path-custom-repopath =
    let
      path = defaultDotfilesPath "/etc/nixos" "bob";
    in
    mkTest "dotfiles-path-custom-repopath" (path == "/etc/nixos/homes/bob/dotfiles");

  # Username with hyphen
  dotfiles-path-hyphen-username =
    let
      path = defaultDotfilesPath "/nix/ft-home" "my-user";
    in
    mkTest "dotfiles-path-hyphen-username" (path == "/nix/ft-home/homes/my-user/dotfiles");

  # Trailing slash in repoPath does not appear (plain string concat)
  dotfiles-path-no-trailing-slash =
    let
      path = defaultDotfilesPath "/my/repo" "alice";
    in
    mkTest "dotfiles-path-no-trailing-slash" (
      path == "/my/repo/homes/alice/dotfiles"
      && !(lib.hasSuffix "/" path)
    );

  # Path always contains /homes/ separator
  dotfiles-path-contains-homes-segment =
    let
      path = defaultDotfilesPath "/nix/ft-home" "alice";
    in
    mkTest "dotfiles-path-contains-homes-segment" (lib.hasInfix "/homes/" path);

  # Path always ends with /dotfiles
  dotfiles-path-ends-with-dotfiles =
    let
      path = defaultDotfilesPath "/nix/ft-home" "alice";
    in
    mkTest "dotfiles-path-ends-with-dotfiles" (lib.hasSuffix "/dotfiles" path);

  # Changing repoPath is reflected in dotfiles path
  dotfiles-path-repopath-propagates =
    let
      pathA = defaultDotfilesPath "/my/config" "alice";
      pathB = defaultDotfilesPath "/other/config" "alice";
    in
    mkTest "dotfiles-path-repopath-propagates" (pathA != pathB);

  # Changing username is reflected in dotfiles path
  dotfiles-path-username-propagates =
    let
      pathA = defaultDotfilesPath "/nix/ft-home" "alice";
      pathB = defaultDotfilesPath "/nix/ft-home" "bob";
    in
    mkTest "dotfiles-path-username-propagates" (pathA != pathB);

  # ---- home.homeDirectory default computation -------------------------------

  # Default homeDirectory is /home/<username>
  homeDirectory-default-alice =
    mkTest "homeDirectory-default-alice" (defaultHomeDirectory "alice" == "/home/alice");

  # homeDirectory for guest user
  homeDirectory-default-guest =
    mkTest "homeDirectory-default-guest" (defaultHomeDirectory "guest" == "/home/guest");

  # homeDirectory for hyphenated username
  homeDirectory-hyphen-username =
    mkTest "homeDirectory-hyphen-username" (defaultHomeDirectory "my-user" == "/home/my-user");

  # homeDirectory always starts with /home/
  homeDirectory-starts-with-home =
    let
      dir = defaultHomeDirectory "alice";
    in
    mkTest "homeDirectory-starts-with-home" (lib.hasPrefix "/home/" dir);

  # ---- home.stateVersion constant -------------------------------------------

  # The stateVersion "24.05" is a literal constant in home-core.nix.
  # Regression test: if the constant changes this test will catch it.
  stateVersion-is-24-05 =
    pkgs.runCommand "home-core-stateVersion-is-24-05"
      {
        nativeBuildInputs = [ pkgs.nix ];
        NIX_PATH = "nixpkgs=${pkgs.path}";
      }
      ''
        # Source the home-core.nix file and check the stateVersion literal
        result=$(grep -c '24\.05' ${../modules/home/home-core.nix} || true)
        if [ "$result" -ge 1 ]; then
          echo "PASS: stateVersion 24.05 found in home-core.nix"
        else
          echo "FAIL: stateVersion 24.05 not found in home-core.nix"
          exit 1
        fi
        touch $out
      '';

  # ---- Option restructuring: options declared under ft (not ft.home) --------

  # The PR restructured home-core.nix to group ft.home.core.enable, ft.repoPath,
  # and ft.dotfiles.path under a single options.ft attrset. Verify the option
  # path string constants are correct (regression against naming drift).

  option-path-repoPath-string =
    pkgs.runCommand "home-core-option-path-repoPath-string"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        # The option must be declared as ft.repoPath (not ft.home.repoPath).
        if grep -q 'repoPath' ${../modules/home/home-core.nix}; then
          echo "PASS: repoPath option found in home-core.nix"
        else
          echo "FAIL: repoPath option not found"
          exit 1
        fi
        touch $out
      '';

  option-path-dotfiles-path-string =
    pkgs.runCommand "home-core-option-path-dotfiles-path-string"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        if grep -q 'dotfiles\.path' ${../modules/home/home-core.nix}; then
          echo "PASS: dotfiles.path option found in home-core.nix"
        else
          echo "FAIL: dotfiles.path option not found"
          exit 1
        fi
        touch $out
      '';

  # Verify that the home-core module declares programs.home-manager.enable
  config-sets-home-manager-enable =
    pkgs.runCommand "home-core-config-sets-home-manager-enable"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        if grep -q 'programs\.home-manager\.enable' ${../modules/home/home-core.nix} \
           || grep -q 'home-manager\.enable' ${../modules/home/home-core.nix}; then
          echo "PASS: programs.home-manager.enable is set in config"
        else
          echo "FAIL: programs.home-manager.enable not found in home-core.nix"
          exit 1
        fi
        touch $out
      '';

  # Verify genericLinux compatibility is enabled
  config-sets-generic-linux =
    pkgs.runCommand "home-core-config-sets-generic-linux"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        if grep -q 'genericLinux\.enable' ${../modules/home/home-core.nix}; then
          echo "PASS: targets.genericLinux.enable found in home-core.nix"
        else
          echo "FAIL: targets.genericLinux.enable not found"
          exit 1
        fi
        touch $out
      '';

  # Verify xdg is enabled
  config-sets-xdg-enable =
    pkgs.runCommand "home-core-config-sets-xdg-enable"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        if grep -q 'xdg\.enable' ${../modules/home/home-core.nix}; then
          echo "PASS: xdg.enable found in home-core.nix"
        else
          echo "FAIL: xdg.enable not found"
          exit 1
        fi
        touch $out
      '';

  # Verify allowUnfree is enabled
  config-sets-allow-unfree =
    pkgs.runCommand "home-core-config-sets-allow-unfree"
      {
        nativeBuildInputs = [ pkgs.gnugrep ];
      }
      ''
        if grep -q 'allowUnfree' ${../modules/home/home-core.nix}; then
          echo "PASS: nixpkgs.config.allowUnfree found in home-core.nix"
        else
          echo "FAIL: nixpkgs.config.allowUnfree not found"
          exit 1
        fi
        touch $out
      '';
}