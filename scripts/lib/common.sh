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
