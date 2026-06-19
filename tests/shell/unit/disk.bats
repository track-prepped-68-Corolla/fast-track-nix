#!/usr/bin/env bats
# Unit tests for scripts/lib/disk.sh

load ../helpers/load

setup() {
  source "${LIB_DIR}/disk.sh"
  cd "${BATS_TEST_TMPDIR}"
}

block_cfg() {
  cat > m.nix <<'EOF'
{ lib, ... }:
{
  ft.diskBtrfs = {
    enable        = true;
    device        = "/dev/nvme0n1";
    confirmDevice = "";
  };
  disko.devices.disk.extra.device = "/dev/sdz";
}
EOF
}

@test "disk_current_device reads the block device" {
  block_cfg
  run disk_current_device m.nix
  [ "$output" = "/dev/nvme0n1" ]
}

@test "disk_current_device ignores unrelated device assignments" {
  block_cfg
  # The disko literal /dev/sdz must never be returned.
  run disk_current_device m.nix
  [ "$output" != "/dev/sdz" ]
}

@test "disk_current_device supports the dotted form" {
  printf '{\n  ft.diskBtrfs.device = "/dev/sda";\n}\n' > m.nix
  run disk_current_device m.nix
  [ "$output" = "/dev/sda" ]
}

@test "disk_current_device is empty when absent" {
  printf '{\n  services.foo.enable = true;\n}\n' > m.nix
  run disk_current_device m.nix
  [ -z "$output" ]
}

@test "disk_write_device rewrites device and confirmDevice in the block" {
  block_cfg
  disk_write_device m.nix /dev/sda
  run disk_current_device m.nix
  [ "$output" = "/dev/sda" ]
  grep -q 'confirmDevice = "/dev/sda";' m.nix
  # unrelated literal untouched
  grep -q 'disko.devices.disk.extra.device = "/dev/sdz";' m.nix
}

@test "disk_write_device inserts confirmDevice when missing, preserving indent" {
  printf '{\n  ft.diskBtrfs = {\n    device = "/dev/nvme0n1";\n  };\n}\n' > m.nix
  disk_write_device m.nix /dev/vda
  grep -q '    device = "/dev/vda";' m.nix
  grep -q '    confirmDevice = "/dev/vda";' m.nix
}

@test "disk_write_device preserves alignment whitespace" {
  block_cfg
  disk_write_device m.nix /dev/sda
  # original used aligned spacing: `device        = "..."`
  grep -q 'device        = "/dev/sda";' m.nix
}
