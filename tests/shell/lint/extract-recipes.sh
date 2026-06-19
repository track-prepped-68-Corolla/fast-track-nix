#!/usr/bin/env bash
# Extract each bash recipe body from a justfile into a standalone .sh file so it
# can be linted with shellcheck. just's {{...}} interpolations are replaced with
# a placeholder token (a valid shell word), and a `# shellcheck disable=SC1091`
# line is injected after the shebang so sourced lib/ files don't trip "not
# following" errors.
#
# Usage: extract-recipes.sh <justfile> <output-dir>
set -euo pipefail

JUSTFILE="${1:?usage: extract-recipes.sh <justfile> <output-dir>}"
OUTDIR="${2:?usage: extract-recipes.sh <justfile> <output-dir>}"
BASENAME="$(basename "$JUSTFILE" .just)"
mkdir -p "$OUTDIR"

awk -v outdir="$OUTDIR" -v prefix="$BASENAME" '
  function flush(   fname) {
    if (inbody && hasbang) {
      fname = outdir "/" prefix "__" name ".sh"
      printf "%s", buf > fname
      close(fname)
    }
    inbody = 0; hasbang = 0; buf = ""; name = ""
  }
  # Recipe header: a name at column 0 ending in ":" — excluding assignments
  # (":="), settings ("set "), imports/aliases, and comments.
  /^@?[A-Za-z_][A-Za-z0-9_-]*([ \t]+[^:]*)?:/ && !/:=/ && !/^set / && !/^import / && !/^alias / {
    flush()
    hdr = $0; sub(/^@/, "", hdr); sub(/:.*/, "", hdr)
    split(hdr, a, /[ \t]/); name = a[1]
    inbody = 1
    next
  }
  inbody {
    if ($0 ~ /^( {4}|\t)/ || $0 ~ /^[ \t]*$/) {
      line = $0; sub(/^( {4}|\t)/, "", line)
      if (line ~ /#!.*bash/) { hasbang = 1; buf = line "\n# shellcheck disable=SC1091\n"; next }
      buf = buf line "\n"
    } else {
      flush()
    }
  }
  END { flush() }
' "$JUSTFILE"

# Replace {{ ... }} interpolations with a placeholder shell word so shellcheck
# parses the bodies. Done as a post-pass to keep the awk above readable.
for f in "$OUTDIR/${BASENAME}__"*.sh; do
  [ -e "$f" ] || continue
  sed -i -E 's/\{\{[^}]*\}\}/JUST_INTERP/g' "$f"
done
