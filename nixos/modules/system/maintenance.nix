{ config, lib, pkgs, ... }:

################################################################################
# FAST TRACK MAINTENANCE MODULE ("ft" CLI)
# ------------------------------------------------------------------------------
# A unified, aesthetic CLI for managing your NixOS system.
#
# COMMANDS:
# ft fmt                        -> Format all .nix files.
# ft check                      -> Verify flake validity (no build).
# ft test                       -> Dry run / Temporary switch (reboot reverts).
# ft upd | update               -> Update flake.lock (get new package versions).
# ft gen | switch | generate    -> Build -> Switch -> Ask to Commit.
# ft pull                       -> Git pull and sync.
# ft push                       -> Git push to remote.
################################################################################

let
  cfg = config.ft.maintenance;

  # ----------------------------------------------------------------------------
  # THE "ft" APPLICATION
  # ----------------------------------------------------------------------------
  ftScript = pkgs.writeShellApplication {
    name = "ft";
    
    # 1. RUNTIME INPUTS (Dependencies)
    # These tools are automatically available in the script's PATH.
    runtimeInputs = with pkgs; [
      git               
      lix               # Faster Nix implementation
      nixfmt-rfc-style  
      nh                # Build helper
      delta             # Diff visualizer
      findutils         
      nvd               
    ];

    # 2. THE SCRIPT
    text = ''
      set -e 

      # --- CONFIGURATION ---
      # This variable is injected from your Host Configuration file.
      FLAKE_DIR="${cfg.flakeDir}"
      
      # --- STYLING (Themed via Stylix) ---
      BOLD=$(tput bold)
      BLUE=$(tput setaf 4)
      GREEN=$(tput setaf 2)
      RED=$(tput setaf 1)
      RESET=$(tput sgr0)

      header()  { echo -e "\n''${BOLD}''${BLUE}:: $1 ::''${RESET}"; }
      success() { echo -e "\n''${BOLD}''${GREEN}✅ $1''${RESET}"; }
      error()   { echo -e "\n''${BOLD}''${RED}❌ $1''${RESET}"; }

      # --- 1. FORMAT ---
      do_fmt() {
        header "✨ Formatting Code"
        find "$FLAKE_DIR" -name "*.nix" -exec nixfmt {} +
        success "Code formatted."
      }

      # --- 2. CHECK ---
      do_check() {
        do_fmt
        header "🛡️  Checking Flake Validity"
        lix flake check "$FLAKE_DIR" --show-trace
        success "Flake is valid."
      }

      # --- 3. TEST (Dry Run) ---
      do_test() {
        do_fmt
        header "🧪 Testing Configuration (Dry Run)"
        
        # Show Side-by-Side Diff
        git -C "$FLAKE_DIR" add .
        git -C "$FLAKE_DIR" diff --cached | delta --side-by-side

        nh os test "$FLAKE_DIR" --ask
        success "Test complete. Reboot to revert changes."
      }

      # --- 4. UPDATE (Lockfile only) ---
      do_update() {
        header "🔄 Updating Flake Inputs (flake.lock)"
        lix flake update --flake "$FLAKE_DIR"
        success "Flake inputs updated. Run 'ft gen' to apply them."
      }

      # --- 5. GENERATE (Build & Switch) ---
      do_generate() {
        do_fmt
        header "🚀 Generating System (Build & Switch)"
        
        nh os switch "$FLAKE_DIR" --ask

        echo ""
        read -p "❓ System Active. Stage and Commit changes? [y/N]: " choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
          header "💾 Committing"
          
          git -C "$FLAKE_DIR" add .
          
          # Show Side-by-Side Diff before committing
          git -C "$FLAKE_DIR" diff --cached | delta --side-by-side
          
          echo ""
          read -p "📝 Commit Message: " msg
          git -C "$FLAKE_DIR" commit -m "$msg"
          success "Changes committed to git."
        else
          echo "Changes applied but NOT committed."
        fi
      }

      # --- 6. GIT SYNC ---
      do_pull() {
        header "⬇️  Pulling from Remote"
        git -C "$FLAKE_DIR" pull --rebase --autostash
        
        header "📄 Incoming Changes"
        # Show Side-by-Side Diff of what just arrived
        git -C "$FLAKE_DIR" diff HEAD@{1}..HEAD | delta --side-by-side
        
        success "Repo synced."
      }

      do_push() {
        header "⬆️  Pushing to Remote"
        if [[ -n $(git -C "$FLAKE_DIR" status --porcelain) ]]; then
           error "You have uncommitted changes. Run 'ft gen' or commit manually first."
           exit 1
        fi
        git -C "$FLAKE_DIR" push
        success "Pushed to remote."
      }

      # --- ROUTING ---
      case "$1" in
        fmt)                     do_fmt ;;
        check)                   do_check ;;
        test)                    do_test ;;
        upd|update)              do_update ;;
        gen|switch|generate)     do_generate ;;
        pull)                    do_pull ;;
        push)                    do_push ;;
        *)
          echo "Usage: ft {fmt|check|test|upd|gen|pull|push}"
          exit 1
          ;;
      esac
    '';
  };

in
{
  # ----------------------------------------------------------------------------
  # OPTIONS
  # ----------------------------------------------------------------------------
  options.ft.maintenance = {
    enable = lib.mkEnableOption "the 'ft' maintenance CLI";
    
    flakeDir = lib.mkOption {
      type = lib.types.str;
      description = "The absolute path to your NixOS flake directory.";
      example = "/home/username/git/nixos-config";
    };
  };

  # ----------------------------------------------------------------------------
  # CONFIG
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ftScript ];

    environment.sessionVariables = {
      NH_FLAKE = cfg.flakeDir;
    };
  };
}