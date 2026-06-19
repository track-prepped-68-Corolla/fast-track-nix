# --- Bootstrap & Provisioning ---

# Initialize git repo and set remote URL.
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
    GIT_REMOTE=$(_rp "remote"    "Remote URL (e.g. git@github.com:you/your-repo)")
    git init
    git config user.name  "$GIT_NAME"
    git config user.email "$GIT_EMAIL"
    git remote add origin "$GIT_REMOTE" 2>/dev/null || git remote set-url origin "$GIT_REMOTE"
    mkdir -p var/local
    printf '%s' "$(nix eval --impure --expr 'builtins.currentSystem' --raw)" > var/local/system
    # repoPath is fixed to the @src convention (see disko-btrfs.nix), not the
    # transient $PWD bootstrap happens to run from — deploy/deploy-local bundle
    # this repo onto /src/<name> via nixos-anywhere --extra-files, so this value
    # must already reflect where the repo will live once the target is installed.
    printf '%s' "/src/$(basename "$PWD")" > var/local/repoPath
    git add var/git/ -f var/local/
    git diff --cached --quiet || git commit -m "chore: store git config and local state in var"
    echo ":: Git initialised. Remote: $GIT_REMOTE ::"

# Initialize tailscale config.
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
    if ! sops --decrypt var/secrets/shared/tailscale.yaml 2>/dev/null | grep -q auth-key; then
      read -rsp "Tailscale auth key (input hidden): " TS_KEY; echo
      printf 'auth-key: "%s"\n' "$TS_KEY" | sops --encrypt --input-type yaml \
        --output var/secrets/shared/tailscale.yaml /dev/stdin
    fi
    git add var/tailscale/ var/secrets/shared/tailscale.yaml
    git diff --cached --quiet || git commit -m "chore: tailscale config"
    echo ":: Tailscale configured for tailnet: $TS_TAILNET ::"

# Scaffold a new machine in machines/<name>/.
# Pass the primary username as the third argument (defaults to "example").
add-machine name ip user="example":
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    USER="{{user}}"
    MACHINE_DIR="machines/${NAME}"
    # var/local state is global bootstrap bookkeeping, not part of the
    # machine's own scaffold — write and commit it unconditionally so it's
    # still recorded even when MACHINE_DIR already exists (e.g. a prebuilt,
    # hand-written machine config rather than one from add-machine's template).
    SYSTEM="$(nix eval --impure --expr 'builtins.currentSystem' --raw)"
    mkdir -p var/local
    printf '%s' "$NAME"   > var/local/machineName
    printf '%s' "$SYSTEM" > var/local/system
    git add var/local/
    git diff --cached --quiet || git commit -m "bootstrap: record local machine state for ${NAME}"
    if [ -d "$MACHINE_DIR" ]; then
      echo ":: Machine ${NAME} already exists at ${MACHINE_DIR} ::"
    else
      mkdir -p "${MACHINE_DIR}/modules"
      mkdir -p "${MACHINE_DIR}/var"
      printf '%s\n' \
        '{ lib, ... }:' \
        '{' \
        '  imports = [' \
        '    ./modules' \
        '    ../../modules/nixos' \
        '  ];' \
        '' \
        "  networking.hostName = \"${NAME}\";" \
        '' \
        '  ft.users = {' \
        "    mainUser = \"${USER}\";" \
        "    superUsers = [ \"${USER}\" ];" \
        '  };' \
        "  users.users.${USER}.initialPassword = \"nixos\";" \
        '  users.mutableUsers = true;' \
        '' \
        '  ft.repoPath = lib.strings.trim (builtins.readFile ../../var/local/repoPath);' \
        '  ft.limine.enable = true;' \
        '  ft.plasma.enable = true;' \
        '  ft.cli.enable = true;' \
        '' \
        '  ft.mullet = {' \
        '    enable     = true;' \
        "    sourcePath = ../../users/${USER}/var/mullet.txt;" \
        '  };' \
        '' \
        '  ft.sops = {' \
        '    enable = true;' \
        '    useTPM = true;' \
        '  };' \
        '' \
        '  ft.facter = {' \
        '    enable     = true;' \
        '    reportPath = ./var/facter.json;' \
        '  };' \
        '' \
        '  ft.core.stateVersion = "25.05";' \
        "  nixpkgs.hostPlatform = \"${SYSTEM}\";" \
        '}' \
        > "${MACHINE_DIR}/default.nix"
      printf '%s\n' \
        '{ lib, ... }:' \
        'let' \
        '  allFiles = lib.filesystem.listFilesRecursive ./.;' \
        '  validModules = builtins.filter (' \
        '    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix' \
        '  ) allFiles;' \
        'in' \
        '{' \
        '  imports = validModules;' \
        '}' \
        > "${MACHINE_DIR}/modules/default.nix"
      git add "${MACHINE_DIR}/"
      git diff --cached --quiet || git commit -m "bootstrap: scaffold machine ${NAME}"
      echo ":: Machine ${NAME} scaffolded at ${MACHINE_DIR} ::"
    fi
    # Always (re)generate facts, even on retry — otherwise a failed first
    # attempt leaves facter.json permanently missing once the directory exists,
    # since the early-return above would silently skip this on every retry.
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" generate-facts "${NAME}" "${IP}"

# Generate SSH host key + derive age pubkey; create var/secrets/.sops.yaml if absent.
secrets-init name:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    SECRETS_DIR="var/secrets"
    SOPS_YAML="${SECRETS_DIR}/.sops.yaml"
    mkdir -p "$TMPDIR" "$SECRETS_DIR"
    if [ ! -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      ssh-keygen -t ed25519 -N "" -f "${TMPDIR}/ssh_host_ed25519_key" -C "root@${NAME}"
    fi
    AGE_KEY=$(ssh-to-age < "${TMPDIR}/ssh_host_ed25519_key.pub")
    echo ":: Age pubkey for ${NAME}: ${AGE_KEY} ::"
    if [ ! -f "$SOPS_YAML" ]; then
      {
        printf 'keys:\n'
        printf '  - &%s %s\n' "$NAME" "$AGE_KEY"
        printf '\n'
        printf 'creation_rules:\n'
        printf '  - path_regex: var/secrets/.*\\.yaml$\n'
        printf '    key_groups:\n'
        printf '      - age:\n'
        printf '        - *%s\n' "$NAME"
      } > "$SOPS_YAML"
      git add "$SOPS_YAML"
      git diff --cached --quiet || git commit -m "bootstrap: initialise sops config for ${NAME}"
      echo ":: Created ${SOPS_YAML} ::"
    else
      echo ":: ${SOPS_YAML} already exists — add this line to its keys section: ::"
      echo "     - &${NAME} ${AGE_KEY}"
      CANDIDATE_FILES=$(find "$SECRETS_DIR" -name '*.yaml' ! -name '.sops.yaml')
      if [ -z "$CANDIDATE_FILES" ]; then
        echo ":: No files exist under ${SECRETS_DIR} yet, so there is nothing to run sops on. ::"
      else
        # sops resolves .sops.yaml by walking up from the current working
        # directory, not from the target file's path, so commands below
        # must be run with cwd inside (or below) $SECRETS_DIR.
        for f in $CANDIDATE_FILES; do
          rel="${f#"$SECRETS_DIR"/}"
          if grep -q '^sops:' "$f"; then
            echo ":: ${f} is already sops-encrypted — run this to sync its keys: ::"
            echo "     (cd ${SECRETS_DIR} && sops updatekeys ${rel})"
          else
            echo ":: ${f} is not sops-encrypted yet — run this to encrypt it with the current rules: ::"
            echo "     (cd ${SECRETS_DIR} && sops ${rel})"
          fi
        done
      fi
    fi

# SSH into target and collect hardware facts into machines/<name>/var/facter.json.
generate-facts name ip:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    mkdir -p "machines/${NAME}/var"
    echo ":: Scanning hardware on ${IP} ::"
    ssh "root@${IP}" \
      "nix run github:numtide/nixos-facter -- -o /tmp/facter.json && cat /tmp/facter.json" \
      > "machines/${NAME}/var/facter.json"
    git add "machines/${NAME}/var/facter.json"
    git diff --cached --quiet || git commit -m "bootstrap: hardware facts for ${NAME}"
    echo ":: machines/${NAME}/var/facter.json written ::"

# Install NixOS on target via nixos-anywhere; confirms the OS disk interactively first.
deploy name ip:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    MACHINE_CFG="machines/${NAME}/default.nix"
    # Confirm disk device before formatting — select-disk.sh shows lsblk output
    # from the target, requires explicit wipe confirmation, and writes both
    # ft.diskBtrfs.device and confirmDevice into $MACHINE_CFG.
    set +e
    NEW_DEVICE=$(bash "{{justfile_directory()}}/select-disk.sh" "$MACHINE_CFG" "root@${IP}")
    SELECT_RC=$?
    set -e
    if [ "$SELECT_RC" -eq 0 ]; then
      git add "$MACHINE_CFG"
      git diff --cached --quiet || git commit -m "bootstrap: set OS disk to ${NEW_DEVICE} for ${NAME}"
    elif [ "$SELECT_RC" -ne 2 ]; then
      echo "Disk selection failed or was declined; aborting deploy." >&2
      exit 1
    fi
    # Bundle this repo onto the target's @src subvolume (mounted at /src) so
    # ft.repoPath (set to /src/<name> by git-init) resolves to a real, persistent
    # location once the target is installed — see disko-btrfs.nix.
    REPO_NAME="$(basename "$PWD")"
    mkdir -p "${TMPDIR}/src"
    rm -rf "${TMPDIR}/src/${REPO_NAME}"
    cp -a "$PWD" "${TMPDIR}/src/${REPO_NAME}"
    if [ -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      mkdir -p "${TMPDIR}/etc/ssh"
      cp "${TMPDIR}/ssh_host_ed25519_key"     "${TMPDIR}/etc/ssh/"
      cp "${TMPDIR}/ssh_host_ed25519_key.pub" "${TMPDIR}/etc/ssh/"
    fi
    nixos-anywhere --flake ".#${NAME}" --extra-files "${TMPDIR}" "root@${IP}"

# Install NixOS on this machine from the live ISO (nixos-anywhere via root@localhost).
deploy-local name:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    MACHINE_CFG="machines/${NAME}/default.nix"
    # Confirm disk device — select-disk.sh shows lsblk output for this machine,
    # requires explicit wipe confirmation, and writes both ft.diskBtrfs.device
    # and confirmDevice into $MACHINE_CFG.
    set +e
    NEW_DEVICE=$(bash "{{justfile_directory()}}/select-disk.sh" "$MACHINE_CFG")
    SELECT_RC=$?
    set -e
    if [ "$SELECT_RC" -eq 0 ]; then
      git add "$MACHINE_CFG"
      git diff --cached --quiet || git commit -m "bootstrap: set OS disk to ${NEW_DEVICE} for ${NAME}"
    elif [ "$SELECT_RC" -ne 2 ]; then
      echo "Disk selection failed or was declined; aborting deploy." >&2
      exit 1
    fi
    # Bundle this repo onto the target's @src subvolume (mounted at /src) so
    # ft.repoPath (set to /src/<name> by git-init) resolves to a real, persistent
    # location once the target is installed — see disko-btrfs.nix.
    REPO_NAME="$(basename "$PWD")"
    mkdir -p "${TMPDIR}/src"
    rm -rf "${TMPDIR}/src/${REPO_NAME}"
    cp -a "$PWD" "${TMPDIR}/src/${REPO_NAME}"
    if [ -f "${TMPDIR}/ssh_host_ed25519_key" ]; then
      mkdir -p "${TMPDIR}/etc/ssh"
      cp "${TMPDIR}/ssh_host_ed25519_key"     "${TMPDIR}/etc/ssh/"
      cp "${TMPDIR}/ssh_host_ed25519_key.pub" "${TMPDIR}/etc/ssh/"
    fi
    nixos-anywhere --flake ".#${NAME}" --phases disko,install --no-reboot --extra-files "${TMPDIR}" root@localhost

# Full bootstrap: git-init → add-machine (includes generate-facts) → secrets-init → deploy.
bootstrap name ip:
    #!/usr/bin/env bash
    set -e
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" git-init 2>/dev/null || true
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" add-machine "{{name}}" "{{ip}}"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" secrets-init "{{name}}"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" deploy "{{name}}" "{{ip}}"
    echo ":: Bootstrap complete for {{name}} ::"

# Full local bootstrap (on live ISO): git-init → add-machine → secrets-init → deploy-local.
bootstrap-local name:
    #!/usr/bin/env bash
    set -e
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" git-init 2>/dev/null || true
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" add-machine "{{name}}" "localhost"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" secrets-init "{{name}}"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" deploy-local "{{name}}"
    echo ":: Bootstrap complete for {{name}} ::"
