# shellcheck shell=bash
# drives.sh — pure helpers for the bulk-drive recipes. These depend on jq
# (shipped with the ft CLI) but on nothing privileged, so they are unit-testable
# without touching real block devices.

# Pick the role bucket a bulk-* label belongs to, from its name.
# Usage: drives_role_for_label <label>  ->  parity | cache | data
drives_role_for_label() {
  case "$1" in
    *parity*) printf 'parity' ;;
    *cache*)  printf 'cache' ;;
    *)        printf 'data' ;;
  esac
}

# Compute the next free label for a role: bulk-<role>-<N>, where N is one past
# the highest trailing number already registered for that role in the JSON
# state ({"parity":[...],"data":[...],"cache":[...]}).
# Usage: drives_next_label <role> <state-json>
drives_next_label() {
  local role="$1" json="$2" max=0 n label
  while IFS= read -r label; do
    [ -z "$label" ] && continue
    n=$(printf '%s' "$label" | grep -oE '[0-9]+$' || echo 0)
    [ "$n" -gt "$max" ] && max="$n"
  done < <(printf '%s' "$json" | jq -r --arg r "$role" '.[$r][]' 2>/dev/null || true)
  printf 'bulk-%s-%s' "$role" "$((max + 1))"
}

# Render the bulk-drives.nix file body from the JSON state. Single source of
# truth for the format written by drives-format, drives-sync and drives-clear.
# Usage: drives_render <state-json>
drives_render() {
  local json="$1" p d c
  p=$(printf '%s' "$json" | jq -r '[.parity[]] | map("\"" + . + "\"") | join(" ")')
  d=$(printf '%s' "$json" | jq -r '[.data[]]   | map("\"" + . + "\"") | join(" ")')
  c=$(printf '%s' "$json" | jq -r '[.cache[]]  | map("\"" + . + "\"") | join(" ")')
  printf '# Managed by ft drives-format and ft drives-sync. Clear with ft drives-clear.\n'
  printf '{\n'
  printf '  parity = [ %s ];\n' "$p"
  printf '  data   = [ %s ];\n' "$d"
  printf '  cache  = [ %s ];\n' "$c"
  printf '}\n'
}
