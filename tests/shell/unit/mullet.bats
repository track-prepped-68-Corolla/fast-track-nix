#!/usr/bin/env bats
# Unit tests for scripts/lib/mullet.sh

load ../helpers/load

setup() {
  source "${LIB_DIR}/mullet.sh"
  cd "${BATS_TEST_TMPDIR}"
  printf 'ripgrep\nfd\n' > mullet.txt
}

@test "mullet_contains finds a present package" {
  run mullet_contains mullet.txt ripgrep
  [ "$status" -eq 0 ]
}

@test "mullet_contains rejects an absent package" {
  run mullet_contains mullet.txt bat
  [ "$status" -ne 0 ]
}

@test "mullet_contains tolerates surrounding whitespace" {
  printf '  ripgrep  \n' > mullet.txt
  run mullet_contains mullet.txt ripgrep
  [ "$status" -eq 0 ]
}

@test "mullet_add_line appends" {
  mullet_add_line mullet.txt bat
  run tail -n1 mullet.txt
  [ "$output" = "bat" ]
}

@test "mullet_rm_line removes only the named package" {
  mullet_rm_line mullet.txt ripgrep
  run cat mullet.txt
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "fd" ]
}
