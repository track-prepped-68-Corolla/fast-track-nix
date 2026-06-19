#!/usr/bin/env bats
# Unit tests for scripts/lib/drives.sh (depends on jq)

load ../helpers/load

setup() {
  source "${LIB_DIR}/drives.sh"
  cd "${BATS_TEST_TMPDIR}"
}

@test "drives_role_for_label classifies by name" {
  [ "$(drives_role_for_label bulk-parity-1)" = "parity" ]
  [ "$(drives_role_for_label bulk-cache-2)" = "cache" ]
  [ "$(drives_role_for_label bulk-data-3)" = "data" ]
  [ "$(drives_role_for_label bulk-something)" = "data" ]
}

@test "drives_next_label starts at 1 for an empty role" {
  run drives_next_label data '{"parity":[],"data":[],"cache":[]}'
  [ "$output" = "bulk-data-1" ]
}

@test "drives_next_label is one past the highest existing number" {
  run drives_next_label data '{"parity":[],"data":["bulk-data-1","bulk-data-3"],"cache":[]}'
  [ "$output" = "bulk-data-4" ]
}

@test "drives_next_label is per-role" {
  run drives_next_label parity '{"parity":["bulk-parity-2"],"data":["bulk-data-9"],"cache":[]}'
  [ "$output" = "bulk-parity-3" ]
}

@test "drives_render produces the managed file format" {
  run drives_render '{"parity":["bulk-parity-1"],"data":["bulk-data-1","bulk-data-2"],"cache":[]}'
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "# Managed by"* ]]
  [ "${lines[1]}" = "{" ]
  [ "${lines[2]}" = '  parity = [ "bulk-parity-1" ];' ]
  [ "${lines[3]}" = '  data   = [ "bulk-data-1" "bulk-data-2" ];' ]
  [ "${lines[4]}" = '  cache  = [  ];' ]
  [ "${lines[5]}" = "}" ]
}
