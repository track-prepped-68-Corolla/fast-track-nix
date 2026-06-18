#!/usr/bin/env bash
# select-disk.sh — interactive OS-disk selection for ft.diskBtrfs.
#
# Lists block devices (excluding the disk backing the running live
# environment's own root filesystem), shows a numbered menu, requires an
# explicit wipe confirmation, then writes both ft.diskBtrfs.device and
# ft.diskBtrfs.confirmDevice into the given machine config so the eval-time
# assertion in disko-btrfs.nix passes. Used by bootstrap.just's deploy and
# deploy-local recipes before nixos-anywhere runs.
#
# Usage: select-disk.sh <machine-config-path> [ssh-target]
#   ssh-target   e.g. root@1.2.3.4 — when set, disks are listed/inspected on
#                that host over ssh; when omitted, disks are listed locally.
#
# On success, prints the resolved device path (e.g. /dev/sda) as the only
# line on stdout; everything else goes to stderr. Exit codes:
#   0  a device was selected and written to the machine config
#   1  no candidate disks were found, or the user declined the final
#      confirmation — callers should treat this as a hard failure
#   2  no ft.diskBtrfs.device assignment exists yet in the machine config —
#      callers should skip disk selection and continue, not treat as fatal

set -euo pipefail

MACHINE_CFG="${1:?usage: select-disk.sh <machine-config-path> [ssh-target]}"
SSH_TARGET="${2:-}"

log() { printf '%s\n' "$*" >&2; }

run() {
  if [ -n "$SSH_TARGET" ]; then
    ssh "$SSH_TARGET" "$1"
  else
    bash -c "$1"
  fi
}

CURRENT_DEVICE=$(grep -oP 'device\s*=\s*"\K[^"]+' "$MACHINE_CFG" 2>/dev/null | head -1 || true)
if [ -z "$CURRENT_DEVICE" ]; then
  log ":: No ft.diskBtrfs.device assignment found in ${MACHINE_CFG} — skipping disk selection. ::"
  exit 2
fi

# Identify the disk backing the live environment's own root filesystem so it
# is never offered as an install target.
BOOT_DISK=$(
  run 'root_dev=$(findmnt -n -o SOURCE / | sed "s/\[.*\]//"); lsblk -n -o PKNAME "$root_dev" 2>/dev/null | head -1' \
    || true
)

log ":: Disks visible on ${SSH_TARGET:-this machine} (current: ${CURRENT_DEVICE}) ::"
mapfile -t CANDIDATES < <(
  run "lsblk -d -n -o NAME,SIZE,MODEL,TYPE 2>/dev/null | grep disk" | awk -v boot="$BOOT_DISK" '$1 != boot'
)

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  log "No candidate disks found (besides the boot disk, ${BOOT_DISK:-unknown})."
  exit 1
fi

for i in "${!CANDIDATES[@]}"; do
  printf "  %2d)  %s\n" "$((i + 1))" "${CANDIDATES[$i]}" >&2
done
log ""

read -rp "Select OS disk [1-${#CANDIDATES[@]}] (or type a device name) [${CURRENT_DEVICE}]: " SEL
SEL="${SEL:-$CURRENT_DEVICE}"

if [[ "$SEL" =~ ^[0-9]+$ ]] && [ "$SEL" -ge 1 ] && [ "$SEL" -le "${#CANDIDATES[@]}" ]; then
  DEV_NAME=$(awk '{print $1}' <<< "${CANDIDATES[$((SEL - 1))]}")
  NEW_DEVICE="/dev/${DEV_NAME}"
else
  NEW_DEVICE="$SEL"
  [[ "$NEW_DEVICE" != /dev/* ]] && NEW_DEVICE="/dev/${NEW_DEVICE}"
fi

log ""
log ":: Selected ${NEW_DEVICE} ::"
run "lsblk -d -o NAME,SIZE,MODEL,TYPE --noheadings '${NEW_DEVICE}' 2>/dev/null" >&2 || true
log ""
read -rp "This WIPES ALL DATA on ${NEW_DEVICE}. This is IRREVERSIBLE. Continue? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[yY]$ ]] || { log "Aborted."; exit 1; }

if [ "$NEW_DEVICE" != "$CURRENT_DEVICE" ]; then
  sed -i "s|device = \"${CURRENT_DEVICE}\"|device = \"${NEW_DEVICE}\"|" "$MACHINE_CFG"
fi

if grep -qE 'confirmDevice[[:space:]]*=' "$MACHINE_CFG"; then
  sed -i -E "s|confirmDevice[[:space:]]*=[[:space:]]*\"[^\"]*\"|confirmDevice = \"${NEW_DEVICE}\"|" "$MACHINE_CFG"
else
  sed -i "s|device = \"${NEW_DEVICE}\"|device = \"${NEW_DEVICE}\"\n    confirmDevice = \"${NEW_DEVICE}\"|" "$MACHINE_CFG"
fi

log ":: ft.diskBtrfs.device and confirmDevice set to ${NEW_DEVICE} in ${MACHINE_CFG} ::"
printf '%s\n' "$NEW_DEVICE"
