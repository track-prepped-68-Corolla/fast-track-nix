# ~/.config/nixos/justfile

# Suppress all command echoing globally for a cleaner terminal
set quiet := true

# Import project-specific modules (Commented out until files exist)
# !include modules/ai/justfile
# !include modules/nas/justfile
# !include user/projects/justfile

default:
    just --list

alias r  := switch
alias t  := test
alias c  := check
alias cl := clean
alias s  := sync

# --- 1. Maintenance & Checks ---

fmt:
    echo ":: Formatting ::"
    find . -name "*.nix" -exec nixfmt {} +

check: fmt
    echo ":: Scanning for leaked secrets ::"
    trufflehog git file://. --since-commit HEAD --fail 2>/dev/null

clean:
    echo ":: Cleaning Nix Store ::"
    nh clean all

# --- 2. Testing ---

test: check
    #!/usr/bin/env bash
    echo ":: Staging & Diffs ::"
    git add .
    git diff --cached | delta --side-by-side
    
    echo ":: Running Test ::"
    nh os test . --ask
    echo ":: Test complete. Reboot to revert. ::"

# --- 3. Core Workflow ---

switch: check
    #!/usr/bin/env bash
    set -e
    echo ":: Previewing Build ::"
    git add .
    nh os test . --dry
    
    echo ":: Source Code Changes ::"
    git diff --cached | delta --side-by-side
    
    read -p "Apply and commit? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      # Build and switch
      nh os switch 
      
      # Extract new generation and diff packages
      GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)
      NVD_DIFF=$(nvd --color never diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2))
      
      # ONLY commit and clean up if there are actual changes
      if ! git diff --cached --quiet; then
          echo ""
          read -p "Commit message: " msg
          git commit -m "$msg" -m "Generation: $GEN" -m "$NVD_DIFF"
          
          # Drop the absolute oldest generation (keeping at least a few for safety)
          GEN_COUNT=$(ls -d1v /nix/var/nix/profiles/system-*-link | wc -l)
          if [ "$GEN_COUNT" -gt 3 ]; then
              OLDEST_LINK=$(ls -d1v /nix/var/nix/profiles/system-*-link | head -n 1)
              OLDEST_GEN=$(basename "$OLDEST_LINK" | cut -d'-' -f2)
              echo ":: Dropping oldest generation ($OLDEST_GEN) ::"
              sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations "$OLDEST_GEN"
          fi
      else
          echo ":: No source changes detected. Skipping git commit and cleanup. ::"
      fi
      
      echo ":: Update Complete! Now running Generation $GEN ::"
    else
      echo "Cancelled."
      exit 1
    fi

# --- 4. Remote Syncing ---

pull:
    echo ":: Pulling Updates ::"
    git pull --rebase --autostash
    
    echo ":: Incoming Source Changes ::"
    git diff HEAD@{1}..HEAD | delta --side-by-side
    
    echo ":: Building and Switching ::"
    nh os switch . --ask
    
    echo ":: System Package Changes ::"
    nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2)

push:
    #!/usr/bin/env bash
    if [[ -n $(git status --porcelain) ]]; then
      echo ":: Error: Uncommitted changes. Run 'just switch' or commit manually first. ::"
      exit 1
    fi
    echo ":: Pushing to Remote ::"
    git push

# --- 5. Full Sync ---

sync: pull push