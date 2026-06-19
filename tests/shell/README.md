# ft shell tests

Tests for the bundled `ft` CLI just-recipes (`scripts/`). The pure logic lives
in sourceable helpers under `scripts/lib/`; the recipes and these tests both
consume them, so units run without spinning up `just`, `nix` or `ssh`.

## Layout

```
tests/shell/
  helpers/load.bash        # repo-root discovery, mock + git helpers, ft_run
  unit/                    # bats unit tests for scripts/lib/*.sh
  integration/             # bats tests that drive real `just` recipes / select-disk.sh
                           #   with nix/ssh/sops/lsblk/findmnt mocked
  lint/                    # shellcheck over lib + select-disk.sh and every
                           #   extracted bash recipe body
  run.sh                   # orchestrator: lint + unit + integration
```

## Running

Everything runs in CI via the **Shell Tests** `workflow_dispatch` job
(`.github/workflows/shell-tests.yml`), which builds the `shell-tests` package:

```bash
nix build -L .#shell-tests
```

Locally, inside `nix develop` (which provides `bats`, `shellcheck`, `just`,
`jq`):

```bash
tests/shell/run.sh              # all
tests/shell/run.sh unit         # just the unit tests
tests/shell/run.sh integration
tests/shell/run.sh lint
```

This suite is intentionally **not** part of `nix flake check` — like the VM
tests, it is manual-dispatch only.

## Conventions

- Every test asserts a concrete effect (a file written, a value parsed, an exit
  code), never just that something evaluated.
- Integration tests stub external/destructive commands (`nix`, `ssh`,
  `ssh-keygen`, `ssh-to-age`, `lsblk`, `findmnt`) via `setup_mockbin` + `mock`
  and operate on a throwaway git repo in `$BATS_TEST_TMPDIR`. No real host,
  network, or block device is touched.
