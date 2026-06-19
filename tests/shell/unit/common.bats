#!/usr/bin/env bats
# Unit tests for scripts/lib/common.sh

load ../helpers/load

setup() {
  source "${LIB_DIR}/common.sh"
  cd "${BATS_TEST_TMPDIR}"
}

@test "gitignore_add appends the pattern" {
  gitignore_add .gitignore "/var/git/"
  run cat .gitignore
  [ "$status" -eq 0 ]
  [ "$output" = "/var/git/" ]
}

@test "gitignore_add is idempotent" {
  gitignore_add .gitignore "/var/git/"
  gitignore_add .gitignore "/var/git/"
  gitignore_add .gitignore "/var/git/"
  run wc -l < .gitignore
  [ "$output" -eq 1 ]
}

@test "gitignore_add preserves existing entries" {
  printf '/foo\n' > .gitignore
  gitignore_add .gitignore "/var/git/"
  run cat .gitignore
  [ "${lines[0]}" = "/foo" ]
  [ "${lines[1]}" = "/var/git/" ]
}

@test "is_json_object accepts an object" {
  printf '{}' > a.json
  run is_json_object a.json
  [ "$status" -eq 0 ]
}

@test "is_json_object accepts an object with leading content" {
  printf '{ "system": "x86_64-linux" }\n' > a.json
  run is_json_object a.json
  [ "$status" -eq 0 ]
}

@test "is_json_object rejects an empty file" {
  : > a.json
  run is_json_object a.json
  [ "$status" -ne 0 ]
}

@test "is_json_object rejects non-JSON" {
  printf 'error: boom\n' > a.json
  run is_json_object a.json
  [ "$status" -ne 0 ]
}
