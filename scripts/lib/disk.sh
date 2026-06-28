# shellcheck shell=bash
# disk.sh — pure helpers for reading and rewriting ft.diskBtrfs.device in a
# machine's default.nix. Extracted from select-disk.sh so the parsing/rewrite
# logic can be unit-tested without enumerating real block devices.

# Echo the ft.diskBtrfs.device currently set in a machine config, or nothing.
# The search is scoped to the ft.diskBtrfs block and anchored at the start of
# the line so an unrelated `device = "..."` (e.g. a disko literal) or the
# `confirmDevice` line is never mistaken for it. Falls back to the dotted form
# (ft.diskBtrfs.device = "...") when no block is used.
# Usage: disk_current_device <machine-config>
disk_current_device() {
  local cfg="$1" dev
  dev=$(
    sed -n '/ft\.diskBtrfs[[:space:]]*=/,/};/p' "$cfg" 2>/dev/null \
      | grep -oP '^\s*device\s*=\s*"\K[^"]+' | head -1 || true
  )
  if [ -z "$dev" ]; then
    dev=$(grep -oP '^\s*ft\.diskBtrfs\.device\s*=\s*"\K[^"]+' "$cfg" 2>/dev/null | head -1 || true)
  fi
  printf '%s' "$dev"
}

# Rewrite ft.diskBtrfs.device (and confirmDevice) to a new value, in place,
# within the ft.diskBtrfs block only. `device` is anchored at line start so the
# substring inside `confirmDevice` is never matched; alignment whitespace around
# `=` is preserved; and a missing confirmDevice is inserted reusing the device
# line's own indentation, so the result stays correctly formatted regardless of
# the original style.
# Usage: disk_write_device <machine-config> <new-device>
disk_write_device() {
  local cfg="$1" new="$2"
  local range='/ft\.diskBtrfs[[:space:]]*=/,/};/'

  sed -i -E "${range} s|^([[:space:]]*)device([[:space:]]*=[[:space:]]*\")[^\"]*(\")|\1device\2${new}\3|" "$cfg"

  if sed -n "${range}p" "$cfg" | grep -qE '^[[:space:]]*confirmDevice[[:space:]]*='; then
    sed -i -E "${range} s|^([[:space:]]*)confirmDevice([[:space:]]*=[[:space:]]*\")[^\"]*(\")|\1confirmDevice\2${new}\3|" "$cfg"
  else
    sed -i -E "${range} s|^([[:space:]]*)device([[:space:]]*=[[:space:]]*\"[^\"]*\";)|\1device\2\n\1confirmDevice = \"${new}\";|" "$cfg"
  fi
}
