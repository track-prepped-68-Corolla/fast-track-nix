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
    # Only prompt on an interactive terminal: under non-interactive stdin (CI,
    # piped input, the bootstrap VM test) a blocking read would hang forever, so
    # fall back to the recommended gitignore default instead.
    if [ -t 0 ]; then
      echo ""
      echo "How should your git identity (name + email) be stored in this repo?"
      echo "  1) gitignore  — keep on disk, never commit (recommended)"
      echo "  2) sops       — encrypt and commit (needs var/secrets/.sops.yaml; run secrets-init first)"
      echo "  3) plaintext  — commit name/email to the repo as-is"
      read -rp "Select [1-3] [1]: " ID_CHOICE
    else
      ID_CHOICE=1
    fi
    ID_CHOICE="${ID_CHOICE:-1}"
    case "$ID_CHOICE" in
      3)
        git add -f var/git/ var/local/
        ;;
      2)
        gitignore_add ".gitignore" "/var/git/"
        if command -v sops >/dev/null 2>&1 && [ -f var/secrets/.sops.yaml ]; then
          mkdir -p var/secrets/shared
          # Write then encrypt in place. sops matches its creation rule against
          # the path as given and finds .sops.yaml by walking up from the cwd, so
          # we run from var/secrets with a relative path; piping /dev/stdin would
          # match no rule. umask keeps the brief plaintext window private.
          ( umask 077
            cd var/secrets || exit 1
            printf 'name: "%s"\nemail: "%s"\n' "$GIT_NAME" "$GIT_EMAIL" > shared/git.yaml
            sops --encrypt --in-place shared/git.yaml )
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
    # ft.tailscale reads sops.secrets."tailscale/authkey" from the default sops
    # file (var/secrets/secrets.yaml) — i.e. nested tailscale.authkey — so the
    # key must live there, not in a separate file, or auto-join never finds it.
    SF="var/secrets/secrets.yaml"
    if sops --decrypt "$SF" 2>/dev/null | grep -qE '^[[:space:]]*authkey:'; then
      echo ":: tailscale/authkey already present in ${SF} — leaving as-is. ::"
    else
      read -rsp "Tailscale auth key (input hidden): " TS_KEY; echo
      if [ -f "$SF" ] && grep -q '^sops:' "$SF"; then
        # Existing encrypted secrets file — merge the nested key in place.
        # Requires the operator to be a recipient of ${SF} (a decryptable
        # identity); otherwise sops refuses and prints why.
        ( cd var/secrets || exit 1
          sops set secrets.yaml '["tailscale"]["authkey"]' "\"${TS_KEY}\"" )
      else
        # No encrypted secrets file yet — create it with just the tailscale key
        # and encrypt under the repo's creation rules. Run from var/secrets so
        # sops finds .sops.yaml (it walks up from the cwd); umask keeps the brief
        # plaintext window private.
        ( umask 077
          cd var/secrets || exit 1
          printf 'tailscale:\n    authkey: "%s"\n' "$TS_KEY" > secrets.yaml
          sops --encrypt --in-place secrets.yaml )
      fi
    fi
    git add var/tailscale/ "$SF"
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
        # Match any YAML by basename, not a var/secrets/ prefix: sops matches
        # this regex against the path as given on the CLI and finds .sops.yaml
        # by walking up from the cwd, so recipes run from inside var/secrets with
        # relative paths (where a var/secrets/ prefix would never match).
        printf '  - path_regex: .*\\.ya?ml$\n'
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
    TMP=$(mktemp)
    trap 'rm -f "$TMP"' EXIT
    # Capture facter's JSON to a temp file and only overwrite facter.json once
    # we've confirmed the payload is non-empty JSON, so a failed scan never
    # clobbers a good report (or commits an empty one). nix-command/flakes are
    # enabled inline because a stock NixOS live ISO ships with them disabled.
    if [ "$IP" = "localhost" ]; then
      # Local mode (self-conversion via kexec, or running on the live ISO): run
      # facter on this machine — no ssh-to-self, which a stock distro's sshd
      # often won't accept for root.
      echo ":: Scanning local hardware ::"
      if ! nix --extra-experimental-features "nix-command flakes" \
          run github:numtide/nixos-facter -- -o "$TMP" >/dev/null 2>&1; then
        echo ":: Error: local hardware scan failed. ::" >&2
        exit 1
      fi
    else
      # Remote mode: facter's own stdout/stderr go to the target's /dev/null so
      # only the JSON emitted by `cat` reaches our captured stdout — a progress
      # line or SSH banner would otherwise corrupt the report.
      echo ":: Scanning hardware on ${IP} ::"
      if ! ssh "root@${IP}" \
          'nix --extra-experimental-features "nix-command flakes" run github:numtide/nixos-facter -- -o /tmp/facter.json >/dev/null 2>&1 && cat /tmp/facter.json' \
          > "$TMP"; then
        echo ":: Error: hardware scan over ssh failed for ${IP}. ::" >&2
        exit 1
      fi
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

# Pull a provisioned host's "snowflake" state off the box and commit + push it,
# so git authoritatively reproduces the machine (the lesson from a host whose
# facter.json never left the box). Run from an operator that HAS push access — a
# freshly provisioned host usually does not. `user` defaults to admin (the
# installed system's management account); pass root for a host still in the
# installer.
#
#   facter.json   re-generated on the host and committed (authoritative).
#   sops recipient / OS disk   verified against the host; drift is reported with
#                              the fix, not auto-rewritten (that path is not yet
#                              shell-tested — rewriting .sops.yaml/confirmDevice
#                              blind is destructive).
capture name ip user="admin":
    #!/usr/bin/env bash
    set -euo pipefail
    # shellcheck source=lib/common.sh
    source "{{justfile_directory()}}/lib/common.sh"
    NAME="{{name}}"
    IP="{{ip}}"
    USER="{{user}}"
    REMOTE="${USER}@${IP}"
    MACHINE_CFG="machines/${NAME}/default.nix"
    if [ "$USER" = "root" ]; then SUDO=""; else SUDO="sudo "; fi

    echo ":: Capturing snowflake state from ${REMOTE} for ${NAME} ::"

    # 1) Hardware report — re-run facter on the host (authoritative) and commit.
    mkdir -p "machines/${NAME}/var"
    TMP=$(mktemp)
    trap 'rm -f "$TMP"' EXIT
    if ! ssh "$REMOTE" \
        "${SUDO}nix --extra-experimental-features 'nix-command flakes' run github:numtide/nixos-facter -- -o /tmp/facter.json >/dev/null 2>&1 && cat /tmp/facter.json" \
        > "$TMP"; then
      echo ":: Error: hardware scan over ssh failed for ${REMOTE}. ::" >&2
      exit 1
    fi
    if ! is_json_object "$TMP"; then
      echo ":: Error: facter produced empty or non-JSON output; leaving facter.json untouched. ::" >&2
      exit 1
    fi
    mv "$TMP" "machines/${NAME}/var/facter.json"
    trap - EXIT

    # 2) sops age recipient — derive from the host's REAL ssh host key and check
    #    it against var/secrets/.sops.yaml (verify-only).
    if [ -f var/secrets/.sops.yaml ] && command -v ssh-to-age >/dev/null 2>&1; then
      HOST_AGE=$(ssh "$REMOTE" 'cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age || true)
      if [ -n "$HOST_AGE" ] && ! grep -qF "$HOST_AGE" var/secrets/.sops.yaml; then
        echo ":: WARN: ${NAME}'s on-host sops recipient is not in var/secrets/.sops.yaml:" >&2
        echo "::         ${HOST_AGE}" >&2
        echo "::       Set the &${NAME} recipient to it, then: (cd var/secrets && sops updatekeys <files>). ::" >&2
      fi
    fi

    # 3) OS disk — detect the physical disk backing / on the host (verify-only).
    if [ -f "$MACHINE_CFG" ]; then
      SRC=$(ssh "$REMOTE" "${SUDO}findmnt -no SOURCE /" 2>/dev/null || true)
      if [ -n "$SRC" ]; then
        DISK=$(ssh "$REMOTE" "lsblk -nso NAME '${SRC}' 2>/dev/null | tail -1" || true)
        if [ -n "$DISK" ] && ! grep -qF "\"/dev/${DISK}\"" "$MACHINE_CFG"; then
          echo ":: WARN: ${NAME} is installed on /dev/${DISK}, which is not set as ft.diskBtrfs.device in ${MACHINE_CFG}. ::" >&2
        fi
      fi
    fi

    # Commit + push whatever changed (facter.json at minimum).
    git add "machines/${NAME}/var/facter.json"
    if git diff --cached --quiet; then
      echo ":: No snowflake changes to commit for ${NAME}. ::"
    else
      git commit -m "capture: snowflake state for ${NAME} from ${IP}"
    fi
    git_push_branch

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
    # shellcheck source=lib/common.sh
    source "{{justfile_directory()}}/lib/common.sh"
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
    # nixos_anywhere prefers an installed binary, else `nix run` (see common.sh).
    nixos_anywhere --flake ".#${NAME}" --extra-files "${TMPDIR}" "root@${IP}"
    # Push the snowflakes (facter, disk, sops recipient) committed above so git
    # authoritatively reproduces ${NAME} — never silently local. Warns, does not
    # fail, if the operator has no push access.
    git_push_branch

# Install NixOS on this machine from the live ISO (nixos-anywhere via root@localhost).
deploy-local name:
    #!/usr/bin/env bash
    set -e
    # shellcheck source=lib/common.sh
    source "{{justfile_directory()}}/lib/common.sh"
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
    # nixos_anywhere prefers an installed binary, else `nix run` (see common.sh).
    nixos_anywhere --flake ".#${NAME}" --phases disko,install --no-reboot --extra-files "${TMPDIR}" root@localhost
    # Try to push the snowflakes committed above. A live-ISO/self-provisioned host
    # usually has no push access — git_push_branch then warns (with the `ft capture`
    # pointer) instead of failing, so they can be captured later from an operator.
    git_push_branch

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

# Convert THIS running Linux machine into the framework via kexec — no USB, no
# live ISO. Prepares config, builds a per-machine kexec installer with the full
# target system baked in, then kexecs into it; the image partitions the disk,
# installs offline, and reboots — all unattended. Run as root (kexec needs it).
#
# sops and the consumer repo are wired AFTERWARD (host-key option B): the
# installed system generates a fresh SSH host key on first boot, so on a machine
# with ft.sops.enable, secret-dependent services stay down until you complete the
# post-install steps printed at the end.
bootstrap-kexec name:
    #!/usr/bin/env bash
    set -e
    # shellcheck source=lib/common.sh
    source "{{justfile_directory()}}/lib/common.sh"
    NAME="{{name}}"
    MACHINE_CFG="machines/${NAME}/default.nix"
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" git-init
    # add-machine runs generate-facts; localhost selects facter's local mode.
    just --justfile "{{justfile()}}" --working-directory "$FT_REPO" add-machine "${NAME}" "localhost"
    # Pin + confirm the target disk locally (writes device + confirmDevice). This
    # is the interactive safety gate — nothing prompts after kexec.
    set +e
    NEW_DEVICE=$(bash "{{justfile_directory()}}/select-disk.sh" "$MACHINE_CFG")
    SELECT_RC=$?
    set -e
    if [ "$SELECT_RC" -eq 0 ]; then
      git add "$MACHINE_CFG"
      git diff --cached --quiet || git commit -m "bootstrap: set OS disk to ${NEW_DEVICE} for ${NAME}"
    elif [ "$SELECT_RC" -ne 2 ]; then
      echo "Disk selection failed or was declined; aborting." >&2
      exit 1
    fi
    # Mark the machine for kexec-image generation so .#${NAME}-kexec exists, then
    # build it (bakes the full target system — this can take a while).
    mkdir -p "machines/${NAME}/var"
    touch "machines/${NAME}/var/kexec"
    git add "machines/${NAME}/var/kexec"
    git diff --cached --quiet || git commit -m "bootstrap: enable kexec installer image for ${NAME}"
    # Push the committed config to git BEFORE the destructive wipe so it's never
    # only on a disk we're about to erase. Warns (with the `ft capture` pointer)
    # if this host has no push access.
    git_push_branch
    echo ":: Building kexec installer image for ${NAME} (bakes the full system) ::"
    nix build ".#${NAME}-kexec" -o "/tmp/${NAME}-kexec"
    # Point of no return: confirm before handing off to the unattended installer.
    DEVICE=$(grep -oP 'device\s*=\s*"\K[^"]+' "$MACHINE_CFG" | head -1 || true)
    echo ""
    echo ":: READY TO CONVERT THIS MACHINE ::"
    echo "   kexec will boot an installer that WIPES ${DEVICE:-the configured disk},"
    echo "   installs '${NAME}' unattended, and reboots. This is IRREVERSIBLE."
    read -rp "Type the machine name '${NAME}' to proceed: " CONFIRM
    [ "$CONFIRM" = "${NAME}" ] || { echo "Aborted — nothing was touched."; exit 1; }
    echo ""
    echo ":: After it reboots into '${NAME}', finish setup on the machine: ::"
    echo "     git clone <your remote> /src/${NAME}   # the repo this was built from"
    echo "     ft secrets-init ${NAME}                 # key sops to the new host key"
    echo "     ft switch                               # rebuild with secrets wired"
    echo ""
    echo ":: kexec'ing now — this box goes down and comes back installed ::"
    exec /tmp/${NAME}-kexec
