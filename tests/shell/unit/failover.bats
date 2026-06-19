#!/usr/bin/env bats
# Unit tests for scripts/lib/failover.sh

load ../helpers/load

setup() {
  source "${LIB_DIR}/failover.sh"
  cd "${BATS_TEST_TMPDIR}"
}

@test "failover_extract_attrs strips hash and version, dedups, sorts" {
  cat > log <<'EOF'
building '/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-hello-2.12.drv'
error: '/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-ripgrep-14.1.0.drv' failed
also /nix/store/cccccccccccccccccccccccccccccccc-hello-2.12.drv
EOF
  run failover_extract_attrs log
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "hello" ]
  [ "${lines[1]}" = "ripgrep" ]
}

@test "failover_extract_attrs yields nothing for a log without drv paths" {
  printf 'error: out of memory\n' > log
  run failover_extract_attrs log
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "failover_extract_attrs handles a name with no version suffix" {
  printf "/nix/store/dddddddddddddddddddddddddddddddd-coreutils.drv\n" > log
  run failover_extract_attrs log
  [ "$output" = "coreutils" ]
}
