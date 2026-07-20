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
    echo ":: Next: commit + push it, then \`ft komodo-apply\` to reconcile Komodo ::"
    echo "::   (or wire the sync's git webhook — see NOTES.md). ::"

# Reconcile Komodo with the generated sync over the API — no UI. Creates the
# ResourceSync (git-backed, from `git remote`) if absent, then executes it so
# Komodo pulls containers/komodo-sync.toml and applies the diff. Requires
# KOMODO_URL, KOMODO_API_KEY and KOMODO_API_SECRET in the environment (source
# them from your sops secrets — see NOTES.md).
#   account: git account alias configured in Komodo; defaults to the repo owner.
@komodo-apply account="":
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck source=lib/komodo.sh
    source "{{justfile_directory()}}/lib/komodo.sh"
    # shellcheck source=lib/komodo-api.sh
    source "{{justfile_directory()}}/lib/komodo-api.sh"

    : "${KOMODO_URL:?set KOMODO_URL (e.g. http://localhost:9120)}"
    : "${KOMODO_API_KEY:?set KOMODO_API_KEY}"
    : "${KOMODO_API_SECRET:?set KOMODO_API_SECRET}"

    remote=$(git remote get-url origin 2>/dev/null || true)
    [ -n "$remote" ] || { echo ":: Error: no 'origin' git remote. ::" >&2; exit 1; }
    branch=$(git branch --show-current 2>/dev/null || true)
    [ -n "$branch" ] || branch="main"
    slug=$(komodo_git_slug "$remote")
    host=$(komodo_git_host "$remote")
    sync_name="${slug##*/}-stacks"
    account="{{account}}"
    [ -n "$account" ] || account="${slug%%/*}"

    config=$(jq -nc \
      --arg gp "$host" --arg ga "$account" --arg repo "$slug" --arg br "$branch" \
      '{git_provider:$gp, git_account:$ga, repo:$repo, branch:$br, resource_path:["{{KOMODO_SYNC_FILE}}"], managed:false}')

    echo ":: Ensuring ResourceSync '${sync_name}' on ${KOMODO_URL} ::"
    id=$(komodo_ensure_sync "$KOMODO_URL" "$KOMODO_API_KEY" "$KOMODO_API_SECRET" "$sync_name" "$config")
    echo ":: Executing sync (${id:-$sync_name}) — Komodo pulls + applies {{KOMODO_SYNC_FILE}}. ::"
    komodo_run_sync "$KOMODO_URL" "$KOMODO_API_KEY" "$KOMODO_API_SECRET" "${id:-$sync_name}"
    echo ":: Done. If a changed stack did not redeploy, run \`ft komodo-deploy\` (Komodo #1120). ::"

# Force a Komodo Stack deploy over the API — the reliable path when a sync's
# `deploy = true` does not redeploy a changed stack (Komodo #1120). With no
# argument, deploys every stack named after a containers/*.yaml file.
# Requires KOMODO_URL, KOMODO_API_KEY and KOMODO_API_SECRET in the environment.
@komodo-deploy stack="":
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck source=lib/komodo.sh
    source "{{justfile_directory()}}/lib/komodo.sh"
    # shellcheck source=lib/komodo-api.sh
    source "{{justfile_directory()}}/lib/komodo-api.sh"

    : "${KOMODO_URL:?set KOMODO_URL}"
    : "${KOMODO_API_KEY:?set KOMODO_API_KEY}"
    : "${KOMODO_API_SECRET:?set KOMODO_API_SECRET}"

    if [ -n "{{stack}}" ]; then
      echo ":: Deploying stack '{{stack}}' ::"
      komodo_deploy_stack "$KOMODO_URL" "$KOMODO_API_KEY" "$KOMODO_API_SECRET" "{{stack}}"
    else
      shopt -s nullglob
      for f in containers/*.yaml containers/*.yml; do
        name=$(komodo_stack_name "$f")
        echo ":: Deploying stack '${name}' ::"
        komodo_deploy_stack "$KOMODO_URL" "$KOMODO_API_KEY" "$KOMODO_API_SECRET" "$name"
      done
    fi
