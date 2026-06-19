#!/usr/bin/env bats
# Unit tests for scripts/lib/store.sh

load ../helpers/load

setup() {
  source "${LIB_DIR}/store.sh"
  cd "${BATS_TEST_TMPDIR}"
}

@test "store_parse_cfg emits config and xdg entries, ignores other sections" {
  cat > app.cfg <<'EOF'
[application]
name = Demo

[configuration_files]
.demorc
.config/legacy

[xdg_configuration_files]
demo/config.toml
EOF
  run store_parse_cfg app.cfg
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = $'config\t.demorc' ]
  [ "${lines[1]}" = $'config\t.config/legacy' ]
  [ "${lines[2]}" = $'xdg\tdemo/config.toml' ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "store_parse_cfg strips carriage returns (CRLF files)" {
  printf '[configuration_files]\r\n.demorc\r\n' > app.cfg
  run store_parse_cfg app.cfg
  [ "${lines[0]}" = $'config\t.demorc' ]
}

@test "store_parse_cfg reads a final line without trailing newline" {
  printf '[configuration_files]\n.demorc' > app.cfg
  run store_parse_cfg app.cfg
  [ "${lines[0]}" = $'config\t.demorc' ]
}

@test "store_parse_cfg ignores entries before any section" {
  printf 'stray\n[configuration_files]\n.demorc\n' > app.cfg
  run store_parse_cfg app.cfg
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'config\t.demorc' ]
}
