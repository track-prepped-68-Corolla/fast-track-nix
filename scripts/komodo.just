# Komodo GitOps — generate a resource-sync TOML from containers/*.yaml.
#
# `ft komodo-sync` scans the consumer repo's containers/ directory and writes
# containers/komodo-sync.toml: one git-backed Komodo Stack per compose file, plus
# a self-managing ResourceSync. Commit the file, then point one ResourceSync in
# Komodo at it (a one-time step) — see NOTES.md "Komodo GitOps".

KOMODO_SYNC_FILE := "containers/komodo-sync.toml"

# Generate containers/komodo-sync.toml from every containers/*.yaml compose file.
#   server:  the Komodo Server resource name Periphery connects as (default
#            "Local", matching ft.ociStack / ft.dockervm's serverName default).
#   account: the git account *alias configured in Komodo* for private-repo
#            access; defaults to the repo owner. Pass account="" for a public repo.
@komodo-sync server="Local" account="":
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck source=lib/komodo.sh
    source "{{justfile_directory()}}/lib/komodo.sh"

    if [ ! -d containers ]; then
      echo ":: Error: no containers/ directory here ($(pwd)). ::" >&2
      exit 1
    fi

    remote=$(git remote get-url origin 2>/dev/null || true)
    if [ -z "$remote" ]; then
      echo ":: Error: no 'origin' git remote — Komodo deploys stacks from a git repo. ::" >&2
      exit 1
    fi

    branch=$(git branch --show-current 2>/dev/null || true)
    [ -n "$branch" ] || branch="main"
    slug=$(komodo_git_slug "$remote")
    host=$(komodo_git_host "$remote")
    sync_name="${slug##*/}-stacks"

    account="{{account}}"
    [ -n "$account" ] || account="${slug%%/*}"

    komodo_generate containers "$sync_name" "{{KOMODO_SYNC_FILE}}" \
      "{{server}}" "$host" "$account" "$slug" "$branch" > "{{KOMODO_SYNC_FILE}}"

    count=$(grep -c '^\[\[stack\]\]' "{{KOMODO_SYNC_FILE}}" || true)
    echo ":: Wrote {{KOMODO_SYNC_FILE}} — ${count} stack(s) from containers/*.yaml. ::"
    echo ":: Next: commit it, then create one Komodo ResourceSync pointing at ::"
    echo "::   ${slug} @ ${branch} : {{KOMODO_SYNC_FILE}}   (see NOTES.md). ::"
