{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.system.maintenance;

  # Shared logic injected into multiple commands
  helpers = {
    format = ''
      header "Formatting"
      find "$FLAKE_DIR" -name "*.nix" -exec nixfmt {} +
    '';

    map = ''
      header "Updating Collator Map"
      COLLATOR_FILE="$FLAKE_DIR/collator.nix"
      
      if [ -f "$COLLATOR_FILE" ]; then
        FILES=$(nix-instantiate --eval --json -E "(import $COLLATOR_FILE { lib = import <nixpkgs/lib>; }).imports" 2>/dev/null | jq -r '.[]') || {
          error "Map generation failed. Check syntax!"
          exit 1
        }
        
        echo "/* --- COLLATOR MAP ---" > "$FLAKE_DIR/.map.tmp"
        echo "Generated on: $(date)" >> "$FLAKE_DIR/.map.tmp"
        echo "" >> "$FLAKE_DIR/.map.tmp"
        
        COUNT=0
        for f in $FILES; do
            RELATIVE_PATH=$(realpath --relative-to="$FLAKE_DIR" "$f")
            echo "  - ./$RELATIVE_PATH" >> "$FLAKE_DIR/.map.tmp"
            COUNT=$((COUNT+1))
        done
        
        echo "" >> "$FLAKE_DIR/.map.tmp"
        echo "Total active modules: $COUNT" >> "$FLAKE_DIR/.map.tmp"
        echo "*/" >> "$FLAKE_DIR/.map.tmp"

        sed -i '/\/\* --- COLLATOR MAP ---/,/\*\//d' "$COLLATOR_FILE"
        cat "$FLAKE_DIR/.map.tmp" >> "$COLLATOR_FILE"
        rm "$FLAKE_DIR/.map.tmp"
      fi
    '';
  };

in
{
  config = lib.mkIf cfg.enable {
    
    # Injecting the logic into the core framework
    ft.system.maintenance.commands = {
      
      fmt = ''
        ${helpers.format}
        success "Code formatted."
      '';

      check = ''
        ${helpers.format}
        ${helpers.map}
        header "Checking Flake Validity"
        nix flake check "$FLAKE_DIR" --show-trace
        success "Flake is valid."
      '';

      test = ''
        ${helpers.format}
        ${helpers.map}
        header "Staging"
        git add .
        header "Building System (For Test & NVD)"
        nh os build "$FLAKE_DIR"
        header "Package Version Changes (NVD)"
        nvd diff /run/current-system ./result
        header "Source Code Changes (Delta)"
        git diff --cached | delta --side-by-side
        header "Running Test"
        nh os test "$FLAKE_DIR" --ask
        rm -f ./result
        success "Test complete. Reboot to revert."
      '';

      upd = ''
        header "Updating Flake Inputs (flake.lock)"
        nix flake update --flake "$FLAKE_DIR"
        success "Flake inputs updated. Run 'ft gen' to apply."
      '';

      gen = ''
        ${helpers.format}
        ${helpers.map}
        header "Staging"
        git add .
        header "Building System"
        nh os build "$FLAKE_DIR"
        header "Package Version Changes (NVD)"
        nvd diff /run/current-system ./result
        header "Source Code Changes (Delta)"
        git diff --cached | delta --side-by-side
        
        echo ""
        read -p "Apply and commit? [y/N]: " choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
          header "Switching"
          nh os switch "$FLAKE_DIR"
          header "Committing"
          read -p "Commit message: " msg
          git commit -m "$msg"
          rm -f ./result
          success "Update Complete!"
        else
          rm -f ./result
          echo "Cancelled."
        fi
      '';

      pull = ''
        header "Pulling updates"
        git pull --rebase --autostash
        header "Building System"
        nh os build "$FLAKE_DIR"
        header "Package Version Changes (NVD)"
        nvd diff /run/current-system ./result
        header "Incoming Source Changes (Delta)"
        git diff HEAD@{1}..HEAD | delta --side-by-side
        header "Switching"
        nh os switch "$FLAKE_DIR" --ask
        rm -f ./result
        success "System updated!"
      '';

      push = ''
        header "Pushing to Remote"
        
        # 1. Check for uncommitted changes
        if [[ -n $(git status --porcelain) ]]; then
          error "You have uncommitted changes. Run 'ft gen' or commit manually first."
          exit 1
        fi
        
        # 2. Pre-Push Security Gate
        echo -e "''${BLUE}Running pre-push secret scan...''${RESET}"
        # We pipe output to /dev/null to keep the terminal clean unless it fails
        if ! ${pkgs.trufflehog}/bin/trufflehog git file://"$FLAKE_DIR" --fail > /dev/null 2>&1; then
          error "PUSH ABORTED: TruffleHog detected secrets in your commit history!"
          echo "Run 'ft scan' to see the detailed security report."
          exit 1
        fi
        
        # 3. Safe to push
        git push
        success "Pushed to remote securely."
      '';

      clean = ''
        header "Cleaning Nix Store"
        nh clean all
        success "Nix store cleaned."
      '';
    };

    scan = ''
        header "Scanning for Secrets (TruffleHog)"
        
        # We scan the local git history. The --fail flag ensures the command 
        # throws an exit code of 1 if any secrets are found.
        if ${pkgs.trufflehog}/bin/trufflehog git file://"$FLAKE_DIR" --fail; then
          success "Repository is clean. No leaked secrets found."
        else
          error "TruffleHog detected potential secrets!"
          echo "Please remove the compromised data from your git history."
          exit 1
        fi
      '';
    
    # Optional: Keep your aliases if you prefer short commands in addition to the ft wrapper
    environment.shellAliases = {
      try = "ft test";
      up = "ft gen";
      down = "ft pull";
      cl = "ft clean";
      fmt = "ft fmt";
    };
  };
}