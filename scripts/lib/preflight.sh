# shellcheck shell=bash
# preflight.sh — pure helpers for the deploy pre-flight guard. No nix/ssh, so
# they unit-test in isolation; the _preflight recipe layers the nix eval on top.

# True if $1 is a syntactically valid age recipient (age1 + bech32 body).
# Rejects placeholders like "age1PLACEHOLDER_..." (uppercase) and short stubs.
is_age_recipient() {
  [[ "$1" =~ ^age1[0-9a-z]{55,}$ ]]
}

# Echo the age recipient anchored to "&<name>" in a .sops.yaml, or nothing.
# Matches the YAML-anchor form used by secrets-init: `- &<name> age1...`.
sops_host_recipient() {
  local sops_yaml="$1" name="$2"
  grep -oE "&${name}[[:space:]]+\S+" "$sops_yaml" 2>/dev/null \
    | head -1 | awk '{print $2}'
}

# Succeed (0) only if &<name> in the given .sops.yaml maps to a real age
# recipient; fail (1) if the anchor is missing or still a placeholder/invalid.
sops_recipient_ok() {
  local rec
  rec=$(sops_host_recipient "$1" "$2")
  [ -n "$rec" ] && is_age_recipient "$rec"
}
