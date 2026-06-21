# shellcheck shell=bash
# common.sh — small pure helpers shared across the ft just-recipes.
#
# Every function here is side-effect-light and dependency-free (coreutils only)
# so it can be sourced and unit-tested in isolation, without spinning up just,
# nix, ssh or sops. Recipes source this via {{justfile_directory()}}/lib/.

# Append a pattern to a gitignore file exactly once, idempotently.
# Usage: gitignore_add <gitignore-file> <pattern>
gitignore_add() {
  local file="$1" pat="$2"
  touch "$file"
  grep -qxF "$pat" "$file" || printf '%s\n' "$pat" >> "$file"
}

# True when a file exists, is non-empty, and looks like a JSON object (starts
# with '{'). Used to vet nixos-facter output before it overwrites facter.json.
# Usage: is_json_object <file>
is_json_object() {
  local file="$1"
  [ -s "$file" ] && [ "$(head -c1 "$file")" = "{" ]
}

# Run nixos-anywhere, preferring an installed binary on PATH and falling back to
# `nix run` (flakes enabled inline, so it also works from a stock live ISO). This
# means provisioning works whether or not the operator has it installed, and a
# test harness can stub `nixos-anywhere` on PATH to intercept the call.
# Usage: nixos_anywhere <nixos-anywhere args...>
nixos_anywhere() {
  if command -v nixos-anywhere >/dev/null 2>&1; then
    nixos-anywhere "$@"
  else
    nix run --extra-experimental-features "nix-command flakes" \
      github:nix-community/nixos-anywhere -- "$@"
  fi
}
