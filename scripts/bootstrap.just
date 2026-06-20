# --- Bootstrap & Provisioning ---

# Initialize git repo and set remote URL.
git-init:
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck source=lib/common.sh
    source "{{justfile_directory()}}/lib/common.sh"
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

    # var/git/ caches name + email (personal data). Let the operator decide how
    # it is persisted, defaulting to keeping it on disk only — off the remote.
    echo ""
    echo "How should your git identity (name + email) be stored in this repo?"
    echo "  1) gitignore  — keep on disk, never commit (recommended)"
    echo "  2) sops       — encrypt and commit (needs var/secrets/.sops.yaml; run secrets-init first)"
    echo "  3) plaintext  — commit name/email to the repo as-is"
    read -rp "Select [1-3] [1]: " ID_CHOICE
    ID_CHOICE="${ID_CHOICE:-1}"
    case "$ID_CHOICE" in
      3)
        git add -f var/git/ var/local/
        ;;
      2)
        gitignore_add ".gitignore" "/var/git/"
        if command -v sops >/dev/null 2>&1 && [ -f var/secrets/.sops.yaml ]; then
          mkdir -p var/secrets/shared
          printf 'name: "%s"\nemail: "%s"\n' "$GIT_NAME" "$GIT_EMAIL" \
            | (cd var/secrets && sops --encrypt --input-type yaml \
                --output shared/git.yaml /dev/stdin)
          git add .gitignore var/secrets/shared/git.yaml var/local/
        else
          echo ":: sops or var/secrets/.sops.yaml unavailable — run secrets-init first, then re-run git-init to encrypt. Keeping identity on disk only for now. ::"
          git add .gitignore var/local/
        fi
        ;;
      *)
        gitignore_add ".gitignore" "/var/git/"
        git add .gitignore var/local/
        ;;
    esac
    git diff --cached --quiet || git commit -m "chore: store local state in var"
    echo ":: Git initialised. Remote: $GIT_REMOTE ::"

# Initialize tailscale config.
tailscale-init:
    #!/usr/bin/env bash
    set -euo pipefail
    _rp() {
      local key="$1" prompt="$2"
      if [ -f "var/tailscale/$key" ]; then cat "var/tailscale/$key"; return; fi
      read -rp "$prompt: " val
      mkdir -p var/tailscale
      printf '%s' "$val" > "var/tailscale/$key"
      echo "$val"
    }
    TS_TAILNET=$(_rp "tailnet" "Tailscale tailnet name (e.g. example.ts.net)")
    if [ ! -f var/secrets/.sops.yaml ]; then
      echo ":: var/secrets/.sops.yaml not found — run 'ft secrets-init <machine>' first. ::" >&2
      exit 1
    fi
    if ! sops --decrypt var/secrets/shared/tailscale.yaml 2>/dev/null | grep -q auth-key; then
      read -rsp "Tailscale auth key (input hidden): " TS_KEY; echo
      mkdir -p var/secrets/shared
      # Run sops from inside var/secrets so it finds .sops.yaml — sops walks up
      # from the cwd, not from the target path (same lookup fix as secrets-init).
      # The resolved absolute path still matches the var/secrets/.*\.yaml$ rule.
      ( cd var/secrets && printf 'auth-key: "%s"\n' "$TS_KEY" \
          | sops --encrypt --input-type yaml --output shared/tailscale.yaml /dev/stdin )
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
    # The scaffolded default.nix reads var/local/repoPath at eval time; it is
    # normally written by git-init, but recreate it here so add-machine works
    # standalone (and on retry) instead of producing a config that fails to eval.
    [ -f var/local/repoPath ] || printf '%s' "/src/$(basename "$PWD")" > var/local/repoPath
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
        '  # device/confirmDevice are rewritten by select-disk.sh during deploy.' \
        '  # The default (/dev/nvme0n1) satisfies the disko-btrfs assertion until' \
        '  # then; without this block deploy has no disk layout and install fails.' \
        '  ft.diskBtrfs = {' \
        '    enable        = true;' \
        '    device        = "/dev/nvme0n1";' \
        '    confirmDevice = "";' \
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
    set -euo pipefail
    # shellcheck source=lib/common.sh
    source "{{justfile_directory()}}/lib/common.sh"
    NAME="{{name}}"
    IP="{{ip}}"
    mkdir -p "machines/${NAME}/var"
    echo ":: Scanning hardware on ${IP} ::"
    TMP=$(mktemp)
    trap 'rm -f "$TMP"' EXIT
    # Send nixos-facter's own stdout/stderr to the remote's /dev/null so only the
    # JSON emitted by `cat` reaches our captured stdout — a progress line or SSH
    # banner would otherwise corrupt the report. Capture to a temp file and only
    # overwrite facter.json once we've confirmed the payload is non-empty JSON,
    # so a failed scan never clobbers a good report (or commits an empty one).
    if ! ssh "root@${IP}" \
        'nix run github:numtide/nixos-facter -- -o /tmp/facter.json >/dev/null 2>&1 && cat /tmp/facter.json' \
        > "$TMP"; then
      echo ":: Error: hardware scan over ssh failed for ${IP}. ::" >&2
      exit 1
    fi
    if ! is_json_object "$TMP"; then
      echo ":: Error: facter produced empty or non-JSON output; leaving machines/${NAME}/var/facter.json untouched. ::" >&2
      exit 1
    fi
    mv "$TMP" "machines/${NAME}/var/facter.json"
    trap - EXIT
    git add "machines/${NAME}/var/facter.json"
    git diff --cached --quiet || git commit -m "bootstrap: hardware facts for ${NAME}"
    echo ":: machines/${NAME}/var/facter.json written ::"

# Pre-flight safety checks. Run by deploy/deploy-local before nixos-anywhere
# touches any disk. BLOCK conditions (exit 1) would brick the install or
# silently fail first boot; WARN conditions are surfaced but allowed.
_preflight name:
    #!/usr/bin/env bash
    set -uo pipefail
    # shellcheck source=lib/preflight.sh
    source "{{justfile_directory()}}/lib/preflight.sh"
    NAME="{{name}}"
    FLAKE=".#nixosConfigurations.${NAME}"
    rc=0
    fail() { echo ":: BLOCK: $* ::" >&2; rc=1; }
    warn() { echo ":: WARN:  $* ::" >&2; }

    # One eval forces the toplevel derivation, so failed assertions, a missing
    # var/local/repoPath, syntax errors, or an unreadable facter.json all surface
    # HERE — before any disk is wiped — and returns the ft.* facts vetted below.
    ERRLOG=$(mktemp)
    if ! facts=$(nix eval --json "$FLAKE" --apply \
        'm: let c = m.config; in builtins.seq c.system.build.toplevel.drvPath {
            sops   = c.ft.sops.enable or false;
            facter = c.ft.facter.enable or false;
            ssh    = c.ft.ssh.enable or false;
            keys   = builtins.length (c.ft.ssh.authorizedKeys or [ ]);
         }' 2>"$ERRLOG"); then
      fail "nixosConfigurations.${NAME} does not evaluate — fix before deploying:"
      sed 's/^/      /' "$ERRLOG" >&2
      rm -f "$ERRLOG"
      echo ":: Pre-flight FAILED — nothing was touched. ::" >&2
      exit 1
    fi
    rm -f "$ERRLOG"

    sops_on=$(printf '%s' "$facts" | jq -r '.sops')
    facter_on=$(printf '%s' "$facts" | jq -r '.facter')
    ssh_on=$(printf '%s' "$facts" | jq -r '.ssh')
    keys=$(printf '%s' "$facts" | jq -r '.keys')

    # sops: if enabled, this host needs a real age recipient or first-boot
    # decryption fails (taking any secret-dependent service down with it).
    if [ "$sops_on" = "true" ]; then
      if [ ! -f var/secrets/.sops.yaml ]; then
        fail "ft.sops.enable but var/secrets/.sops.yaml is missing — run 'ft secrets-init ${NAME}'."
      elif ! sops_recipient_ok var/secrets/.sops.yaml "$NAME"; then
        fail "ft.sops.enable but the &${NAME} recipient in var/secrets/.sops.yaml is a placeholder/invalid — secrets won't decrypt on first boot. Run 'ft secrets-init ${NAME}', paste the printed key over the placeholder, then '(cd var/secrets && sops updatekeys <files>)'."
      fi
    fi

    # facter wiring (warn only): a report nobody reads, or one expected but absent.
    FACTER="machines/${NAME}/var/facter.json"
    if [ -f "$FACTER" ] && [ "$facter_on" != "true" ]; then
      warn "${FACTER} exists but ft.facter.enable is false — the hardware report is ignored. Add an ft.facter block (enable = true; reportPath = ./var/facter.json;)."
    elif [ ! -f "$FACTER" ] && [ "$facter_on" = "true" ]; then
      warn "ft.facter.enable but ${FACTER} is missing — run 'ft generate-facts ${NAME} <ip>' (no hardware detection until then)."
    fi

    # ssh keys (warn only): enabled, but no key can log in.
    if [ "$ssh_on" = "true" ] && [ "$keys" = "0" ]; then
      warn "ft.ssh.enable but ft.ssh.authorizedKeys is empty — key login won't work (password only)."
    fi

    if [ "$rc" -ne 0 ]; then
      echo ":: Pre-flight FAILED — aborting before any disk is touched. ::" >&2
    else
      echo ":: Pre-flight OK for ${NAME}. ::"
    fi
    exit "$rc"

# Install NixOS on target via nixos-anywhere; confirms the OS disk interactively first.
deploy name ip:
    #!/usr/bin/env bash
    set -e
    NAME="{{name}}"
    IP="{{ip}}"
    TMPDIR="/tmp/bootstrap-${NAME}"
    MACHINE_CFG="machines/${NAME}/default.nix"
    # Fail before touching any disk if the config won't evaluate or would brick
    # first boot (sops recipient placeholder, etc.).
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _preflight "$NAME"
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
    # Fail before touching any disk if the config won't evaluate or would brick
    # first boot (sops recipient placeholder, etc.).
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" _preflight "$NAME"
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
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" git-init
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" add-machine "{{name}}" "{{ip}}"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" secrets-init "{{name}}"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" deploy "{{name}}" "{{ip}}"
    echo ":: Bootstrap complete for {{name}} ::"

# Full local bootstrap (on live ISO): git-init → add-machine → secrets-init → deploy-local.
bootstrap-local name:
    #!/usr/bin/env bash
    set -e
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" git-init
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" add-machine "{{name}}" "localhost"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" secrets-init "{{name}}"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" deploy-local "{{name}}"
    echo ":: Bootstrap complete for {{name}} ::"
