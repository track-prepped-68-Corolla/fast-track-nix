#!/usr/bin/env bats
# Integration tests for select-disk.sh with lsblk/findmnt mocked, so disk
# enumeration and the interactive selection run without real block devices.

load ../helpers/load

setup() {
  setup_mockbin
  cd "${BATS_TEST_TMPDIR}"
  cat > m.nix <<'EOF'
{ lib, ... }:
{
  ft.diskBtrfs = {
    enable        = true;
    device        = "/dev/nvme0n1";
    confirmDevice = "";
  };
}
EOF
  mock findmnt 'printf "/dev/vda1\n"'
  mock lsblk '
    case "$*" in
      *PKNAME*)        printf "vda\n" ;;
      *--noheadings*)  printf "sdb 200G WD disk\n" ;;
      *NAME,SIZE,MODEL,TYPE*) printf "vda 20G QEMU disk\nsda 100G Samsung disk\nsdb 200G WD disk\n" ;;
    esac
  '
}

@test "rewrites the chosen device and prints it on stdout" {
  # menu (boot disk vda excluded): 1) sda  2) sdb  -> pick 2, confirm
  run bash "${SCRIPTS_DIR}/select-disk.sh" m.nix 2>/dev/null <<EOF
2
y
EOF
  [ "$status" -eq 0 ]
  [ "$output" = "/dev/sdb" ]
  grep -q 'device        = "/dev/sdb";' m.nix
  grep -q 'confirmDevice = "/dev/sdb";' m.nix
}

@test "aborts and leaves the config untouched on declined confirmation" {
  run bash "${SCRIPTS_DIR}/select-disk.sh" m.nix 2>/dev/null <<EOF
2
n
EOF
  [ "$status" -eq 1 ]
  grep -q 'device        = "/dev/nvme0n1";' m.nix
}

@test "exits 2 when the config has no ft.diskBtrfs device" {
  printf '{ services.foo.enable = true; }\n' > none.nix
  run bash "${SCRIPTS_DIR}/select-disk.sh" none.nix 2>/dev/null
  [ "$status" -eq 2 ]
}
