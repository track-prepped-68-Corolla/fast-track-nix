# Shared bats helpers for the ft shell test suite.
#
# Locates the repo root (and thus scripts/) by walking up from the test file
# until flake.nix is found, so it works regardless of a test's nesting depth.

_ft_find_root() {
  local d="${BATS_TEST_DIRNAME}"
  while [ "$d" != "/" ]; do
    [ -e "$d/flake.nix" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

REPO_ROOT="$(_ft_find_root)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"
export REPO_ROOT SCRIPTS_DIR LIB_DIR

# Create a private directory for mock executables and prepend it to PATH.
# Call from a test's setup() before defining mocks.
setup_mockbin() {
  MOCKBIN="${BATS_TEST_TMPDIR}/mockbin"
  mkdir -p "$MOCKBIN"
  PATH="${MOCKBIN}:${PATH}"
  export MOCKBIN PATH
}

# Define a mock executable on PATH.
# Usage: mock <name> <line-of-body>...
# The body runs under bash; "$@" is the mock's args.
mock() {
  local name="$1"
  shift
  {
    printf '#!/usr/bin/env bash\n'
    printf '%s\n' "$@"
  } > "${MOCKBIN}/${name}"
  chmod +x "${MOCKBIN}/${name}"
}

# Initialise a throwaway git repo at $1 with a deterministic identity, so
# recipes that commit work inside the test sandbox.
init_git_repo() {
  git init -q "$1"
  git -C "$1" config user.email "test@example.com"
  git -C "$1" config user.name "Test"
  git -C "$1" config commit.gpgsign false
}

# Run an ft recipe against a consumer repo, faithfully mirroring the ft wrapper
# (bash shell, real scripts/ justfile, --working-directory = the repo, FT_REPO set).
# Usage: ft_run <repo> <recipe> [args...]
ft_run() {
  local repo="$1"
  shift
  FT_REPO="$repo" just \
    --shell bash \
    --justfile "${SCRIPTS_DIR}/ft.just" \
    --working-directory "$repo" \
    "$@"
}
