{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# SYSTEM MAINTENANCE MODULE
# ------------------------------------------------------------------------------
# This module provides a powerful and user-friendly CLI (`nh` and `ft` commands)
# for managing your NixOS flake configuration. It includes features for
# formatting code, checking flake validity, testing configurations, updating
# flake inputs, switching generations, and synchronizing with Git repositories.
################################################################################

let
  cfg = config.ft.system.maintenance;

  # --- Format Command ---
  # Formats all .nix files within the flake directory using nixfmt.
  formatCmd = ''
    echo "--- ✨ Formatting ---"
    ${pkgs.findutils}/bin/find "$FLAKE_DIR" -name "*.nix" -exec ${pkgs.nixfmt}/bin/nixfmt {} +
  '';

  # --- Script 1: nh-test (Dry Run / Temporary Switch) ---
  # Tests the configuration without making permanent changes. Reboot to revert.
  nhTestScript = pkgs.writeShellScriptBin "nh-test" ''
    set -e
    FLAKE_DIR="${cfg.flakeDir}"

    ${formatCmd}

    echo "--- 🛠️  Staging ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" add .

    echo "--- 📄 Source Code Changes (Delta) ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" diff --cached | ${pkgs.delta}/bin/delta

    echo "--- 🧪 Running Test ---"
    ${pkgs.nh}/bin/nh os test "$FLAKE_DIR" --ask
    echo "✅ Test complete. Reboot to revert." 
  '';

  # --- Script 2: nh-update (Commit & Switch) ---
  # Updates flake inputs, builds, switches to the new generation, and prompts for a Git commit.
  nhUpdateScript = pkgs.writeShellScriptBin "nh-update" ''
    set -e
    FLAKE_DIR="${cfg.flakeDir}"

    ${formatCmd}

    echo "--- 🛠️  Staging ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" add .

    echo "--- 🔍 Previewing Build ---"
    ${pkgs.nh}/bin/nh os test "$FLAKE_DIR" --dry

    echo ""
    echo "--- 📄 Source Code Changes (Delta) ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" diff --cached | ${pkgs.delta}/bin/delta

    echo ""
    read -p "Apply and commit? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      echo "--- 🚀 Switching ---"
      ${pkgs.nh}/bin/nh os switch "$FLAKE_DIR"

      echo "--- 💾 Committing ---"
      read -p "Commit message: " msg
      ${pkgs.git}/bin/git -C "$FLAKE_DIR" commit -m "$msg"
      echo "✅ Update Complete!"
    else
      echo "🛑 Cancelled."
    fi
  '';

  # --- Script 3: nh-sync (Pull & Switch) ---
  # Pulls latest changes from Git, applies them, and switches the system.
  nhSyncScript = pkgs.writeShellScriptBin "nh-sync" ''
    set -e
    FLAKE_DIR="${cfg.flakeDir}"
    echo "--- ⬇️  Pulling updates ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" pull --rebase --autostash

    echo "--- 📄 Incoming Changes (Delta) ---"
    ${pkgs.git}/bin/git -C "$FLAKE_DIR" diff HEAD@{1}..HEAD | ${pkgs.delta}/bin/delta

    echo "--- 🚀 Building and Switching ---"
    ${pkgs.nh}/bin/nh os switch "$FLAKE_DIR" --ask
    echo "✅ System updated!"
  '';

  # --- The 'ft' Application CLI ---
  # This consolidates all maintenance scripts under a single, easy-to-use command.
  ftScript = pkgs.writeShellApplication {
    name = "ft";
    runtimeInputs = with pkgs; [
      git
      lix
      nh
      nixfmt
      delta
      findutils
      nvd
    ];
    text = ''
      set -e
      FLAKE_DIR="${cfg.flakeDir}"

      BOLD=$(tput bold)
      BLUE=$(tput setaf 4)
      GREEN=$(tput setaf 2)
      RED=$(tput setaf 1)
      RESET=$(tput sgr0)

      header()  { echo -e "\n''${BOLD}''${BLUE}:: $1 ::''${RESET}"; }
      success() { echo -e "\n''${BOLD}''${GREEN}✅ $1''${RESET}"; }
      error()   { echo -e "\n''${BOLD}''${RED}❌ $1''${RESET}"; }

      case "$1" in
        fmt)
          ${formatCmd}
          success "Code formatted."
          ;;
        check)
          ${formatCmd}
          header "🛡️  Checking Flake Validity"
          nix flake check "$FLAKE_DIR" --show-trace
          success "Flake is valid."
          ;;
        test)
          ${nhTestScript}/bin/nh-test
          ;;
        upd|update)
          header "🔄 Updating Flake Inputs (flake.lock)"
          nix flake update --flake "$FLAKE_DIR"
          success "Flake inputs updated."
          ;;
        gen|switch|generate)
          ${nhUpdateScript}/bin/nh-update
          ;;
        pull)
          ${nhSyncScript}/bin/nh-sync
          ;;
        push)
          header "⬆️  Pushing to Remote"
          if [[ -n $(git -C "$FLAKE_DIR" status --porcelain) ]]; then
            error "You have uncommitted changes. Run 'ft gen' or commit manually first."
            exit 1
          fi
          git -C "$FLAKE_DIR" push
          success "Pushed to remote."
          ;;
        clean)
          nh clean all
          success "Nix store cleaned."
          ;;
        *)
          echo "Usage: ft {fmt|check|test|upd|gen|pull|push|clean}"
          exit 1
          ;;
      esac
    '';
  };

in
{
  options.ft.system.maintenance = {
    enable = lib.mkEnableOption "System maintenance CLI (nh and ft commands)";

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/joe/git/ft-home";
      description = "The absolute path to your NixOS flake directory.";
      example = "/home/username/git/my-nixos-config";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.lix
      pkgs.nh
      pkgs.nvd
      pkgs.nix-output-monitor
      pkgs.nixfmt
      pkgs.findutils
      pkgs.delta
      pkgs.git
      nhTestScript
      nhUpdateScript
      nhSyncScript
      ftScript
    ];

    environment.sessionVariables = {
      NH_FLAKE = cfg.flakeDir;
    };

    environment.shellAliases = {
      try = "nh-test";
      up = "nh-update";
      down = "nh-sync";
      cl = "nh clean all";
      fmt = "nixfmt";
    };
  };
}
