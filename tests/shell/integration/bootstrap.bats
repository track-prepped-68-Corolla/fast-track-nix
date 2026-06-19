#!/usr/bin/env bats
# Integration tests for bootstrap.just recipes, driven through real `just`
# exactly as the ft wrapper would, with nix/ssh/sops/ssh-keygen mocked so no
# host, network or real provisioning is touched.

load ../helpers/load

setup() {
  setup_mockbin
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME"
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO"
  # `nix eval ... currentSystem` is the only local nix call in these recipes.
  mock nix 'case "$*" in *currentSystem*) printf "x86_64-linux" ;; esac'
}

@test "git-init (gitignore choice) keeps identity out of the commit" {
  init_git_repo "$REPO"
  run ft_run "$REPO" git-init <<EOF
Test User
test@example.com
git@github.com:me/repo
1
EOF
  [ "$status" -eq 0 ]
  [ -f "$REPO/var/local/system" ]
  [ "$(cat "$REPO/var/local/system")" = "x86_64-linux" ]
  [ "$(cat "$REPO/var/local/repoPath")" = "/src/repo" ]
  grep -qxF "/var/git/" "$REPO/.gitignore"
  # var/git (name + email cache) must not be tracked.
  run git -C "$REPO" ls-files var/git
  [ -z "$output" ]
  # but local state is committed
  git -C "$REPO" ls-files var/local/system | grep -q .
}

@test "add-machine scaffolds a disk layout and valid facter.json" {
  init_git_repo "$REPO"
  mock ssh 'printf "{\"system\":\"x86_64-linux\"}\n"'
  run ft_run "$REPO" add-machine strix 1.2.3.4 alice
  [ "$status" -eq 0 ]
  [ -f "$REPO/machines/strix/default.nix" ]
  grep -q 'ft.diskBtrfs' "$REPO/machines/strix/default.nix"
  grep -q 'enable        = true;' "$REPO/machines/strix/default.nix"
  [ -f "$REPO/var/local/repoPath" ]
  # generate-facts ran (recursively) and wrote a JSON report
  [ -f "$REPO/machines/strix/var/facter.json" ]
  head -c1 "$REPO/machines/strix/var/facter.json" | grep -q '{'
}

@test "generate-facts writes and commits valid JSON" {
  init_git_repo "$REPO"
  mock ssh 'printf "{\"system\":\"x86_64-linux\"}\n"'
  run ft_run "$REPO" generate-facts strix 1.2.3.4
  [ "$status" -eq 0 ]
  head -c1 "$REPO/machines/strix/var/facter.json" | grep -q '{'
  git -C "$REPO" ls-files machines/strix/var/facter.json | grep -q .
}

@test "generate-facts refuses to write non-JSON output" {
  init_git_repo "$REPO"
  mock ssh 'printf "error: scan failed\n"'
  run ft_run "$REPO" generate-facts strix 1.2.3.4
  [ "$status" -ne 0 ]
  [ ! -f "$REPO/machines/strix/var/facter.json" ]
}

@test "secrets-init creates a .sops.yaml with the derived age key" {
  init_git_repo "$REPO"
  rm -rf /tmp/bootstrap-strix
  # ssh-keygen mock: create the key + pub at the -f path.
  mock ssh-keygen '
    while [ "$#" -gt 0 ]; do [ "$1" = "-f" ] && { f="$2"; }; shift; done
    mkdir -p "$(dirname "$f")"
    printf "PRIV\n" > "$f"
    printf "ssh-ed25519 AAAAfake root@strix\n" > "$f.pub"
  '
  mock ssh-to-age 'cat >/dev/null; printf "age1testkey0000000000000000000000000000000000000000000000000\n"'
  run ft_run "$REPO" secrets-init strix
  [ "$status" -eq 0 ]
  [ -f "$REPO/var/secrets/.sops.yaml" ]
  grep -q 'age1testkey' "$REPO/var/secrets/.sops.yaml"
  grep -q '&strix' "$REPO/var/secrets/.sops.yaml"
}
