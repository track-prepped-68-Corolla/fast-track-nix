# shellcheck shell=bash
# mullet.sh — pure helpers for the imperative-package list ("The Mullet").
# Entries are one package attribute per line, optionally surrounded by spaces.

# True if pkg is already listed in file.
# Usage: mullet_contains <file> <pkg>
mullet_contains() {
  grep -q "^[[:space:]]*$2[[:space:]]*\$" "$1"
}

# Append pkg to file (caller is responsible for validation / dedup).
# Usage: mullet_add_line <file> <pkg>
mullet_add_line() {
  printf '%s\n' "$2" >> "$1"
}

# Remove every line listing pkg from file, in place.
# Usage: mullet_rm_line <file> <pkg>
mullet_rm_line() {
  sed -i "/^[[:space:]]*$2[[:space:]]*\$/d" "$1"
}
