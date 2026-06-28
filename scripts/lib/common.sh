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

# Push the current branch to origin with exponential backoff (2s, 4s, 8s).
# Warns instead of failing on persistent error, so a credential-less or offline
# host never aborts a bootstrap that already succeeded locally — the commits stay
# local and can be pushed later (e.g. via `ft capture` from a machine that has
# push access). This is what keeps provisioning snowflakes (facter.json, disk
# device, sops recipient) from silently living only on the box.
# Usage: git_push_branch
git_push_branch() {
  local branch delay=2 i
  branch=$(git rev-parse --abbrev-ref HEAD)
  for i in 1 2 3 4; do
    if git push -u origin "$branch"; then
      return 0
    fi
    if [ "$i" -lt 4 ]; then
      echo ":: push failed (attempt ${i}/4) — retrying in ${delay}s ::" >&2
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done
  echo ":: WARN: could not push '${branch}' to origin (no credentials/network?)." >&2
  echo "::       Commits are local. Push from a machine with access, or run there:" >&2
  echo "::         ft capture <name> <ip>   (captures + pushes this host's state) ::" >&2
  return 0
}
