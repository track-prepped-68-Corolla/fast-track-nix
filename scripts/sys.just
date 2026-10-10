# --- 1. Maintenance & Checks ---

fmt:
    echo ":: Formatting ::"
    find . -name "*.nix" -exec nixfmt {} +

check: fmt
    echo ":: Scanning for leaked secrets ::"
    trufflehog git file://. --since-commit HEAD --fail 2>/dev/null

clean:
    echo ":: Cleaning Nix Store ::"
    nh clean all --keep 5

# --- 2. Testing ---

test: check
    #!/usr/bin/env bash
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _check-reqs
    echo ":: Staging & Diffs ::"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _stage
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _diff-src

    echo ":: Running Test ::"
    nh os test . --ask
    echo ":: Test complete. Reboot to revert. ::"

# --- 3. Core Workflow ---

switch: check
    #!/usr/bin/env bash
    set -e
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _check-reqs

    echo ":: Previewing Build ::"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _stage
    nh os test . --dry

    echo ":: Source Code Changes ::"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _diff-src

    read -p "Apply and commit? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      OLD_GEN=$(just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _current-gen)

      just --justfile "{{justfile()}}" --working-directory "$FT_REPO" failover-switch

      # Keep Home Manager on the same nixpkgs as the system. Switching only one
      # side after an update leaves HM apps linked against a different Mesa than
      # /run/opengl-driver, which breaks every GL app (no OpenGL context).
      # Non-fatal: the system switch already succeeded, so still commit it.
      if [ "$(id -u)" -ne 0 ] && [ -d "users/$USER" ] && command -v home-manager >/dev/null; then
        echo ":: Switching Home Manager ::"
        just --justfile "{{justfile()}}" --working-directory "$FT_REPO" home-switch \
          || echo ":: Warning: Home Manager switch failed; re-run 'ft home-switch' after fixing it. ::"
      fi

      GEN=$(just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _current-gen)
      # Tolerate a single-generation system (e.g. first switch): nvd needs two
      # profiles to diff, and under `set -e` a failure here would abort the
      # commit even though the build already succeeded.
      NVD_DIFF=$(nvd --color never diff $(just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _last-two-gens) 2>/dev/null || echo "(no previous generation to diff)")

      if ! git diff --cached --quiet; then
          echo ""
          read -p "Commit message: " msg
          git commit -m "$msg" -m "Generation: $GEN" -m "$NVD_DIFF"
      else
          echo ":: No source changes detected. Skipping git commit. ::"
      fi

      if [ "$GEN" -gt "$OLD_GEN" ]; then
          just --justfile "{{justfile()}}" --working-directory "$FT_REPO" clean
      else
          echo ":: System generation did not change. Skipping cleanup. ::"
      fi

      echo ":: Update Complete! Now running Generation $GEN ::"
    else
      echo "Cancelled."
      exit 1
    fi

home-switch user="" arch="" profiles="":
    #!/usr/bin/env bash
    set -euo pipefail
    # Recipe parameters arrive only through just's interpolation (the double-brace
    # syntax); they are NOT exported as shell variables (no `set export`), so the
    # previous ${user:-...} expansion always saw an unset shell var and silently
    # ignored both arguments. Read them through interpolation, then default here.
    U="{{user}}"; A="{{arch}}"; P="{{profiles}}"
    U="${U:-$USER}"
    A="${A:-$(uname -m)-linux}"

    # The chosen homeConfigurations attr is remembered per user@arch, so a bare
    # `ft home-switch` (and the one `ft switch` runs) re-applies the profile combo
    # you last picked instead of silently dropping back to the base config.
    STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ft/home-config-${U}@${A}"

    if [ "$P" = "none" ]; then
      ATTR="${U}@${A}"
    elif [ -n "$P" ]; then
      # Same naming as the generator: <user>+<p1>+<p2>@<arch>, profiles sorted.
      SORTED=$(tr ',' '\n' <<< "${P// /,}" | sed '/^$/d' | sort -u)
      for prof in $SORTED; do
        if [ ! -d "users/${U}/profiles/${prof}" ]; then
          echo ":: Error: no profile '${prof}' in users/${U}/profiles/ ::" >&2
          exit 1
        fi
      done
      ATTR="${U}+$(paste -sd+ <<< "$SORTED")@${A}"
    elif [ -f "$STATE" ]; then
      ATTR=$(cat "$STATE")
    else
      ATTR="${U}@${A}"
    fi

    echo ":: Home Manager: ${ATTR} ::"
    # -b backup: a first switch for a user commonly collides with dotfiles a
    # desktop session already wrote (e.g. KDE's kdeglobals/kwinrc) before HM
    # ever ran; renaming the conflict aside beats failing the switch outright.
    home-manager switch -b backup --flake ".#${ATTR}"

    mkdir -p "$(dirname "$STATE")"
    printf '%s\n' "$ATTR" > "$STATE"

# --- 4. Remote Syncing ---

pull:
    echo ":: Pulling Updates ::"
    git pull --rebase --autostash

    echo ":: Incoming Source Changes ::"
    git diff HEAD@{1}..HEAD | delta --side-by-side

    echo ":: Building and Switching ::"
    nh os switch . --ask

    echo ":: System Package Changes ::"
    nvd diff $(just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _last-two-gens) 2>/dev/null || echo "(no previous generation to diff)"

push:
    #!/usr/bin/env bash
    if [[ -n $(git status --porcelain) ]]; then
      echo ":: Error: Uncommitted changes. Run 'ft switch' or commit manually first. ::"
      exit 1
    fi
    echo ":: Pushing to Remote ::"
    git push

sync: pull push

# --- 5. Emergency Recovery ---

rollback:
    #!/usr/bin/env bash
    echo ":: Current Generation ::"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _current-gen

    echo ":: Rolling back to previous generation ::"
    sudo nix-env --profile /nix/var/nix/profiles/system --rollback

    echo ":: Activating rolled-back system ::"
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch

    echo ":: Rollback Complete! ::"
    echo ":: Note: Your Git repo is still ahead. You may want to 'git reset' or fix the code. ::"

# --- Internal Helpers ---

_check-reqs:
    #!/usr/bin/env bash
    for cmd in nh nvd delta; do
      if ! command -v $cmd &> /dev/null; then echo "Error: $cmd is not installed."; exit 1; fi
    done

_stage:
    git add .

_diff-src:
    git diff --cached | delta --side-by-side

_current-gen:
    @readlink /nix/var/nix/profiles/system | cut -d'-' -f2

_last-two-gens:
    @ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2
