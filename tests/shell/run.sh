#!/usr/bin/env bash
# Entry point for the ft shell test suite: shellcheck + bats unit + bats
# integration. Run locally inside `nix develop` (which provides bats, shellcheck,
# just, jq) or via the shell-tests Nix package / the workflow_dispatch CI job.
#
# Usage: tests/shell/run.sh [unit|integration|lint]   (default: all)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
what="${1:-all}"

run_lint() { "${HERE}/lint/shellcheck-scripts.sh"; }
run_unit() { echo ":: bats unit ::"; bats "${HERE}/unit"; }
run_integration() { echo ":: bats integration ::"; bats "${HERE}/integration"; }

case "$what" in
  lint)        run_lint ;;
  unit)        run_unit ;;
  integration) run_integration ;;
  all)         run_lint; run_unit; run_integration ;;
  *) echo "usage: run.sh [unit|integration|lint]" >&2; exit 2 ;;
esac

echo ":: shell test suite passed ::"
