# shellcheck shell=bash
# failover.sh — pure helper for failover-switch's package-attr extraction.

# Extract candidate nixpkgs attribute names from the failed .drv paths in a
# build log. Strips the /nix/store/<hash>- prefix and the -<version> suffix.
# Compound names (e.g. python312-requests) collapse to their first segment,
# which may not be the real attribute — manual correction can still be needed,
# but the common case is handled.
# Usage: failover_extract_attrs <build-log>
failover_extract_attrs() {
  local log="$1"
  grep -oP '(?<=/nix/store/[a-z0-9]{32}-)[^/\n]+(?=\.drv)' "$log" \
    | sed 's/-[0-9].*$//' \
    | sort -u \
    | grep -v '^$' || true
}
