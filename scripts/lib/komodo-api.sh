# shellcheck shell=bash
# komodo-api.sh — a thin curl+jq driver for the Komodo Core API, used by the
# `komodo-apply` / `komodo-deploy` recipes to reconcile the generated sync from
# containers/ without touching the Komodo UI.
#
# Komodo Core is API-first: the UI is just a client. Requests are POSTs to
# /read, /write or /execute with X-Api-Key / X-Api-Secret headers and a
# {"type": ..., "params": ...} JSON body. Only curl and jq are needed.
#
# All functions take the connection triple explicitly (base url, api key, api
# secret) so nothing here reads global state — it can be sourced and tested with
# curl/jq mocked, like the other lib/ helpers.

# POST a request to a Komodo API module (read|write|execute). Emits the response
# body on stdout; fails (non-zero, message on stderr) on any non-2xx status.
# Usage: komodo_api <base-url> <key> <secret> <module> <json-body>
komodo_api() {
  local base="$1" key="$2" secret="$3" module="$4" body="$5" resp code
  resp=$(curl -sS -w $'\n%{http_code}' -X POST "${base%/}/${module}" \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: ${key}" \
    -H "X-Api-Secret: ${secret}" \
    -d "${body}") || return 1
  code=${resp##*$'\n'}
  body=${resp%$'\n'*}
  if [ "${code:-0}" -lt 200 ] || [ "${code:-0}" -ge 300 ]; then
    echo ":: Komodo API /${module} failed (HTTP ${code}): ${body} ::" >&2
    return 1
  fi
  printf '%s' "$body"
}

# Look up a ResourceSync id by name; emits the id (empty if none exists).
# Usage: komodo_find_sync_id <base> <key> <secret> <name>
komodo_find_sync_id() {
  local base="$1" key="$2" secret="$3" name="$4" resp
  resp=$(komodo_api "$base" "$key" "$secret" read '{"type":"ListResourceSyncs","params":{}}') || return 1
  printf '%s' "$resp" | jq -r --arg n "$name" 'first(.[]? | select(.name == $n) | .id) // empty'
}

# Create the ResourceSync if absent, otherwise update its config in place. Emits
# the sync id. `config` is a JSON object matching Komodo's ResourceSync config
# (git_provider, git_account, repo, branch, resource_path, managed).
# Usage: komodo_ensure_sync <base> <key> <secret> <name> <config-json>
komodo_ensure_sync() {
  local base="$1" key="$2" secret="$3" name="$4" config="$5" id body resp
  id=$(komodo_find_sync_id "$base" "$key" "$secret" "$name") || return 1
  if [ -n "$id" ]; then
    body=$(jq -nc --arg id "$id" --argjson cfg "$config" \
      '{type:"UpdateResourceSync",params:{id:$id,config:$cfg}}')
    komodo_api "$base" "$key" "$secret" write "$body" >/dev/null || return 1
  else
    body=$(jq -nc --arg name "$name" --argjson cfg "$config" \
      '{type:"CreateResourceSync",params:{name:$name,config:$cfg}}')
    resp=$(komodo_api "$base" "$key" "$secret" write "$body") || return 1
    id=$(printf '%s' "$resp" | jq -r '.id // empty')
  fi
  printf '%s' "$id"
}

# Execute a ResourceSync (pull latest from git + apply the diff). `sync` is the
# sync id or name.
# Usage: komodo_run_sync <base> <key> <secret> <sync>
komodo_run_sync() {
  local base="$1" key="$2" secret="$3" sync="$4" body
  body=$(jq -nc --arg s "$sync" '{type:"RunSync",params:{sync:$s}}')
  komodo_api "$base" "$key" "$secret" execute "$body" >/dev/null
}

# Deploy a single Stack by name (or id). Used to force a redeploy that a sync's
# `deploy = true` does not always trigger (Komodo #1120).
# Usage: komodo_deploy_stack <base> <key> <secret> <stack>
komodo_deploy_stack() {
  local base="$1" key="$2" secret="$3" stack="$4" body
  body=$(jq -nc --arg s "$stack" '{type:"DeployStack",params:{stack:$s}}')
  komodo_api "$base" "$key" "$secret" execute "$body" >/dev/null
}
