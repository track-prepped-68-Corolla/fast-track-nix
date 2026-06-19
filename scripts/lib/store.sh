# shellcheck shell=bash
# store.sh — pure parser for Mackup-style application .cfg files.

# Parse a Mackup .cfg, emitting one "<kind>\t<relpath>" line per managed file.
# kind is "config" for entries under [configuration_files] and "xdg" for entries
# under [xdg_configuration_files]; all other sections are ignored. Carriage
# returns and blank lines are stripped, and a final line without a trailing
# newline is still read. Callers resolve <kind>/<relpath> into absolute source
# and destination paths using $HOME / $XDG_CONFIG_HOME / the dotfiles dir.
# Usage: store_parse_cfg <cfg-file>
store_parse_cfg() {
  local cfg="$1" section="" line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [ -z "$line" ] && continue
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      continue
    fi
    case "$section" in
      configuration_files)     printf 'config\t%s\n' "$line" ;;
      xdg_configuration_files) printf 'xdg\t%s\n' "$line" ;;
    esac
  done < "$cfg"
}
