# ft.just — Fast Track Nix main justfile
# Run via:  ft <recipe>   (wrapper installed by ft.cli.enable = true)
# Or:       just --justfile scripts/ft.just <recipe>

set quiet := true

import "./mullet.just"
import "./store.just"

default:
    just --list

alias r  := switch
alias t  := test
alias c  := check
alias cl := clean
alias s  := sync

# ─── 1. Maintenance & Checks ─────────────────────────────────────────────────

fmt:
    echo ":: Formatting ::"
    find . -name "*.nix" -exec nixfmt {} +

check: fmt
    echo ":: Scanning for leaked secrets ::"
    trufflehog git file://. --since-commit HEAD --fail 2>/dev/null

clean:
    echo ":: Cleaning Nix Store ::"
    nh clean all --keep 5

# ─── 2. Testing ──────────────────────────────────────────────────────────────

test: check
    #!/usr/bin/env bash
    just _check-reqs
    echo ":: Staging & Diffs ::"
    just _stage
    just _diff-src
    echo ":: Running Test ::"
    nh os test . --ask
    echo ":: Test complete. Reboot to revert. ::"

# ─── 3. Core Workflow ────────────────────────────────────────────────────────

switch: check
    #!/usr/bin/env bash
    set -e
    just _check-reqs
    echo ":: Previewing Build ::"
    just _stage
    nh os test . --dry
    echo ":: Source Code Changes ::"
    just _diff-src
    read -p "Apply and commit? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      OLD_GEN=$(just _current-gen)
      nh os switch .
      GEN=$(just _current-gen)
      NVD_DIFF=$(nvd --color never diff $(just _last-two-gens))
      if ! git diff --cached --quiet; then
          echo ""
          read -p "Commit message: " msg
          git commit -m "$msg" -m "Generation: $GEN" -m "$NVD_DIFF"
      else
          echo ":: No source changes detected. Skipping git commit. ::"
      fi
      if [ "$GEN" -gt "$OLD_GEN" ]; then
          just clean
      fi
      echo ":: Update Complete! Now running Generation $GEN ::"
    else
      echo "Cancelled."
      exit 1
    fi

home-switch:
    #!/usr/bin/env bash
    USER="${1:-$USER}"
    ARCH="${2:-$(uname -m)-linux}"
    home-manager switch --flake ".#${USER}@${ARCH}"

# ─── 4. Remote Syncing ───────────────────────────────────────────────────────

pull:
    echo ":: Pulling Updates ::"
    git pull --rebase --autostash
    echo ":: Incoming Source Changes ::"
    git diff HEAD@{1}..HEAD | delta --side-by-side
    echo ":: Building and Switching ::"
    nh os switch . --ask
    echo ":: System Package Changes ::"
    nvd diff $(just _last-two-gens)

push:
    #!/usr/bin/env bash
    if [[ -n $(git status --porcelain) ]]; then
      echo ":: Error: Uncommitted changes. Run 'just switch' or commit manually first. ::"
      exit 1
    fi
    echo ":: Pushing to Remote ::"
    git push

sync: pull push

# ─── 5. Bootstrap ────────────────────────────────────────────────────────────

# Initialize git repo and set remote URL.
# Reads from var/git/ if previously stored, otherwise prompts and saves.
git-init:
    #!/usr/bin/env bash
    set -e
    _rp() {
      local key="$1" prompt="$2"
      if [ -f "var/git/$key" ]; then cat "var/git/$key"; return; fi
      read -rp "$prompt: " val
      mkdir -p var/git
      printf '%s' "$val" > "var/git/$key"
      echo "$val"
    }
    GIT_NAME=$(_rp "user-name"  "Git user name")
    GIT_EMAIL=$(_rp "user-email" "Git user email")
    GIT_REMOTE=$(_rp "remote"    "Remote URL (e.g. git@github.com:you/nixos-config)")
    git init
    git config user.name  "$GIT_NAME"
    git config user.email "$GIT_EMAIL"
    git remote add origin "$GIT_REMOTE" 2>/dev/null || git remote set-url origin "$GIT_REMOTE"
    git add var/git/
    git diff --cached --quiet || git commit -m "chore: store git config in var"
    echo ":: Git initialised. Remote: $GIT_REMOTE ::"

# Initialize tailscale config. Tailnet name stored in var/tailscale/; auth key encrypted via sops.
tailscale-init:
    #!/usr/bin/env bash
    set -e
    _rp() {
      local key="$1" prompt="$2"
      if [ -f "var/tailscale/$key" ]; then cat "var/tailscale/$key"; return; fi
      read -rp "$prompt: " val
      mkdir -p var/tailscale
      printf '%s' "$val" > "var/tailscale/$key"
      echo "$val"
    }
    TS_TAILNET=$(_rp "tailnet" "Tailscale tailnet name (e.g. example.ts.net)")
    if ! sops --decrypt secrets/shared/tailscale.yaml 2>/dev/null | grep -q auth-key; then
      read -rsp "Tailscale auth key (input hidden): " TS_KEY; echo
      printf 'auth-key: "%s"\n' "$TS_KEY" | sops --encrypt --input-type yaml \
        --output secrets/shared/tailscale.yaml /dev/stdin
    fi
    git add var/tailscale/ secrets/shared/tailscale.yaml
    git diff --cached --quiet || git commit -m "chore: tailscale config"
    echo ":: Tailscale configured for tailnet: $TS_TAILNET ::"

# Scaffold a new host in hosts/x86_64-linux/<name>/ and register it in the repo.
add-host hostname:
    #!/usr/bin/env bash
    set -e
    HOSTNAME="{{hostname}}"
    ARCH="${2:-x86_64-linux}"
    HOST_DIR="hosts/${ARCH}/${HOSTNAME}"
    if [ -d "$HOST_DIR" ]; then
      echo ":: Host ${HOSTNAME} already exists at ${HOST_DIR} ::"
      exit 0
    fi
    REPO_PATH="$(git rev-parse --show-toplevel)"
    mkdir -p "$HOST_DIR" "var/${HOSTNAME}"
    printf '%s' "$REPO_PATH" > "var/${HOSTNAME}/repo-path"
    cat > "${HOST_DIR}/default.nix" <<EOF
{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
  ];

  networking.hostName = "${HOSTNAME}";
  mainuser = "joe";

  ft.runtimeFacts.enable = true;
  ft.boot.limine.enable  = true;
  ft.security.sops.enable = true;
  ft.desktop.cosmic.enable = true;
  ft.cli.enable = true;

  # ft.disk.enable  = true;
  # ft.disk.devices = { ... };   # see github.com/nix-community/disko

  programs.zsh.enable = true;
  nixpkgs.hostPlatform = "${ARCH}";
}
EOF
    touch "${HOST_DIR}/hardware-configuration.nix"
    git add "${HOST_DIR}/" "var/${HOSTNAME}/repo-path"
    git diff --cached --quiet || git commit -m "bootstrap: scaffold host ${HOSTNAME}"
    echo ":: Host ${HOSTNAME} scaffolded at ${HOST_DIR} ::"
    echo ":: Next: just facter ${HOSTNAME} <ip>  then  just deploy ${HOSTNAME} <ip> ::"

# Generate the SSH host key, derive age pubkey, and update .sops.yaml for a new host.
secrets-init hostname:
    #!/usr/bin/env bash
    set -e
    HOSTNAME="{{hostname}}"
    TMPDIR="/tmp/bootstrap-${HOSTNAME}"
    mkdir -p "$TMPDIR"
    ssh-keygen -t ed25519 -N "" -f "${TMPDIR}/ssh_host_ed25519_key" -C "root@${HOSTNAME}"
    AGE_KEY=$(ssh-to-age < "${TMPDIR}/ssh_host_ed25519_key.pub")
    echo ":: Age pubkey for ${HOSTNAME}: ${AGE_KEY} ::"
    # TODO: auto-patch secrets/.sops.yaml — for now, print instructions:
    echo ""
    echo "Add this to secrets/.sops.yaml:"
    echo "  - &${HOSTNAME}  ${AGE_KEY}"
    echo "And add *${HOSTNAME} to all relevant creation_rules."
    echo "Then run:  sops updatekeys secrets/shared/*.yaml"
    echo "Key files are in: ${TMPDIR}/"

# SSH into the target and collect hardware facts, then write var/<host>/facts.nix.
facter hostname ip:
    #!/usr/bin/env bash
    set -e
    HOSTNAME="{{hostname}}"
    IP="{{ip}}"
    echo ":: Scanning hardware on ${IP} ::"
    ssh "root@${IP}" \
      "nix run github:numtide/nixos-facter -- -o /tmp/facter.json && cat /tmp/facter.json" \
      > "hosts/x86_64-linux/${HOSTNAME}/facter.json"
    just generate-facts "{{hostname}}"

# Read hosts/<host>/facter.json and write var/<host>/facts.nix.
generate-facts hostname:
    #!/usr/bin/env bash
    set -e
    HOSTNAME="{{hostname}}"
    FACTER="hosts/x86_64-linux/${HOSTNAME}/facter.json"
    if [ ! -f "$FACTER" ]; then
      echo "Error: ${FACTER} not found. Run: just facter ${HOSTNAME} <ip>"; exit 1
    fi
    GPU_VENDOR=$(jq -r '[.hardware.pci_devices[]? | select(.class_id == "0300" or .class_id == "0302") | .vendor_name // "unknown"] | first // "unknown"' "$FACTER" | tr '[:upper:]' '[:lower:]')
    HAS_NVIDIA=$(echo "$GPU_VENDOR" | grep -c nvidia || true)
    HAS_AMD=$(echo "$GPU_VENDOR"    | grep -c amd    || true)
    mkdir -p "var/${HOSTNAME}"
    cat > "var/${HOSTNAME}/facts.nix" <<EOF
{
  hostname    = "${HOSTNAME}";
  arch        = "x86_64-linux";
  primaryUser = "joe";
  gpu = {
    vendor      = "${GPU_VENDOR}";
    hasDiscrete = false;
    hasNvidia   = $([ "$HAS_NVIDIA" -gt 0 ] && echo true || echo false);
    hasAmd      = $([ "$HAS_AMD"    -gt 0 ] && echo true || echo false);
  };
}
EOF
    git add "var/${HOSTNAME}/facts.nix" "${FACTER}"
    git diff --cached --quiet || git commit -m "bootstrap: hardware facts for ${HOSTNAME}"
    echo ":: var/${HOSTNAME}/facts.nix written ::"

# Run nixos-anywhere to install NixOS onto a target machine.
deploy hostname ip:
    #!/usr/bin/env bash
    set -e
    HOSTNAME="{{hostname}}"
    IP="{{ip}}"
    TMPDIR="/tmp/bootstrap-${HOSTNAME}"
    EXTRA_FILES=""
    if [ -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      mkdir -p "${TMPDIR}/etc/ssh"
      cp "${TMPDIR}/ssh_host_ed25519_key"     "${TMPDIR}/etc/ssh/"
      cp "${TMPDIR}/ssh_host_ed25519_key.pub" "${TMPDIR}/etc/ssh/"
      EXTRA_FILES="--extra-files ${TMPDIR}"
    fi
    echo ":: Installing NixOS on ${IP} as ${HOSTNAME} ::"
    nixos-anywhere --flake ".#${HOSTNAME}" $EXTRA_FILES "root@${IP}"

# Full bootstrap: scaffold host → secrets init → hardware scan → deploy.
bootstrap hostname ip:
    #!/usr/bin/env bash
    set -e
    just git-init      2>/dev/null || true
    just add-host      "{{hostname}}"
    just secrets-init  "{{hostname}}"
    just facter        "{{hostname}}" "{{ip}}"
    just deploy        "{{hostname}}" "{{ip}}"
    echo ""
    echo ":: Bootstrap complete for {{hostname}} ::"
    echo ":: After reboot, run on the new machine:  just home-switch ::"

# ─── 6. Emergency Recovery ───────────────────────────────────────────────────

rollback:
    #!/usr/bin/env bash
    echo ":: Current Generation ::"
    just _current-gen
    echo ":: Rolling back to previous generation ::"
    sudo nix-env --profile /nix/var/nix/profiles/system --rollback
    echo ":: Activating rolled-back system ::"
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
    echo ":: Rollback Complete! ::"

# ─── 7. Internal Helpers ─────────────────────────────────────────────────────

_check-reqs:
    #!/usr/bin/env bash
    for cmd in nh nvd delta; do
      if ! command -v $cmd &> /dev/null; then echo "Error: $cmd is not installed."; exit 1; fi
    done

_stage:
    git add .

_diff-src:
    git diff --cached | delta --side-by-side

_current-gen:
    @readlink /nix/var/nix/profiles/system | cut -d'-' -f2

_last-two-gens:
    @ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2
