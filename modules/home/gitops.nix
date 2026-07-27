{
  pkgs,
  lib,
  config,
  ...
}:

# -----------------------------------------------------------------------------
#  ft.gitops — pull-based GitOps for standalone Home Manager
# -----------------------------------------------------------------------------
# comin (the NixOS-side ft.gitops) is a Go daemon with no concept of Home
# Manager — standalone HM has no equivalent. This is a from-scratch
# poll/build/switch/retry loop that plays the same role for a standalone HM
# profile: it clones/pulls a git repo, and on a new (or previously-failing)
# commit on remote.branch, runs `home-manager switch` against it.
#
# Unlike the NixOS side's watchdog-restarts-the-daemon workaround, this daemon
# owns its whole loop, so retry is native: a failed switch just doesn't
# advance the "last applied commit" state, and the next poll tick re-attempts
# the same commit, up to retry.maxAttempts, using pollPeriod as the retry
# cadence.
let
  cfg = config.ft.gitops;

  stateDir = "${config.home.homeDirectory}/.local/state/ft-gitops";
  signingKeysArray = lib.concatMapStringsSep " " lib.escapeShellArg cfg.signingKeys;

  daemonScript = pkgs.writeShellScript "ft-gitops" ''
    set -uo pipefail

    repo_path=${lib.escapeShellArg cfg.repoPath}
    remote_url=${lib.escapeShellArg cfg.remote.url}
    branch=${lib.escapeShellArg cfg.remote.branch}
    flake_attr=${lib.escapeShellArg cfg.flakeAttr}
    max_attempts=${toString cfg.retry.maxAttempts}
    poll_period=${toString cfg.pollPeriod}
    signing_keys=(${signingKeysArray})

    state_dir=${lib.escapeShellArg stateDir}
    applied_file="$state_dir/applied"
    attempt_commit_file="$state_dir/attempt-commit"
    attempt_count_file="$state_dir/attempt-count"

    log() { echo "ft-gitops: $*"; }

    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    if [[ ! -d "$repo_path/.git" ]]; then
      log "cloning $remote_url ($branch) into $repo_path"
      ${pkgs.git}/bin/git clone --branch "$branch" "$remote_url" "$repo_path" \
        || log "initial clone failed, will retry next poll"
    fi

    # Verifies a commit against signing_keys in a scratch keyring, so this
    # never touches the user's normal GPG keyring. An empty signing_keys list
    # skips verification entirely (see the signingKeys option description).
    verify_commit() {
      local commit="$1"
      [[ ''${#signing_keys[@]} -eq 0 ]] && return 0
      local gnupg_dir
      gnupg_dir=$(${pkgs.coreutils}/bin/mktemp -d)
      for key in "''${signing_keys[@]}"; do
        GNUPGHOME="$gnupg_dir" ${pkgs.gnupg}/bin/gpg --batch --quiet --import "$key" 2>/dev/null
      done
      GNUPGHOME="$gnupg_dir" ${pkgs.git}/bin/git -C "$repo_path" verify-commit "$commit" >/dev/null 2>&1
      local result=$?
      ${pkgs.coreutils}/bin/rm -rf "$gnupg_dir"
      return $result
    }

    while true; do
      if [[ -d "$repo_path/.git" ]] && ${pkgs.git}/bin/git -C "$repo_path" fetch origin "$branch" 2>&1; then
        tip=$(${pkgs.git}/bin/git -C "$repo_path" rev-parse "origin/$branch")

        applied=""
        [[ -f "$applied_file" ]] && applied=$(<"$applied_file")

        if [[ "$tip" != "$applied" ]]; then
          attempt_commit=""
          [[ -f "$attempt_commit_file" ]] && attempt_commit=$(<"$attempt_commit_file")
          attempts=0
          [[ -f "$attempt_count_file" ]] && attempts=$(<"$attempt_count_file")

          if [[ "$tip" != "$attempt_commit" ]]; then
            attempts=0
            echo "$tip" > "$attempt_commit_file"
            echo 0 > "$attempt_count_file"
          fi

          if [[ "$attempts" -lt "$max_attempts" ]]; then
            if verify_commit "$tip"; then
              log "switching to $tip (attempt $((attempts + 1))/$max_attempts)"
              ${pkgs.git}/bin/git -C "$repo_path" checkout --quiet --detach "$tip"
              if ${pkgs.home-manager}/bin/home-manager switch --flake "$repo_path#$flake_attr"; then
                log "switch to $tip succeeded"
                echo "$tip" > "$applied_file"
              else
                attempts=$((attempts + 1))
                echo "$attempts" > "$attempt_count_file"
                log "switch to $tip failed (attempt $attempts/$max_attempts)"
              fi
            else
              attempts=$((attempts + 1))
              echo "$attempts" > "$attempt_count_file"
              log "commit $tip failed signature verification (attempt $attempts/$max_attempts)"
            fi
          else
            log "giving up on $tip after $max_attempts attempts; waiting for a new commit"
          fi
        fi
      else
        log "fetch failed, will retry next poll"
      fi

      ${pkgs.coreutils}/bin/sleep "$poll_period"
    done
  '';
in
{
  options.ft.gitops = {
    enable = lib.mkEnableOption "pull-based GitOps for this standalone Home Manager profile" // {
      description = "Runs a background service that keeps a standalone Home Manager profile in sync with a git repo: it clones and pulls `remote.url`, and whenever there's a new commit on `remote.branch`, it runs `home-manager switch` against `homeConfigurations.<flakeAttr>`. If a switch fails, it retries the same commit up to `retry.maxAttempts` times before giving up until a newer commit arrives. This is a from-scratch equivalent of the NixOS side's comin-based `ft.gitops`, built because comin has no concept of Home Manager.";
    };

    remote = {
      url = lib.mkOption {
        type = lib.types.str;
        description = "The git URL this service clones and pulls from.";
      };

      branch = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "The branch this service tracks and deploys.";
      };
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      description = "The local path this service clones the repository into. It's a private checkout used only by this service, separate from any NixOS `ft.repoPath`, since standalone Home Manager may be running on a non-NixOS host.";
    };

    flakeAttr = lib.mkOption {
      type = lib.types.str;
      description = ''Which `homeConfigurations.<flakeAttr>` entry to switch to, e.g. "alice@x86_64-linux".'';
    };

    pollPeriod = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "How often, in seconds, this service checks `remote.url` for new commits.";
    };

    signingKeys = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Armored GPG public key files. A commit only gets switched to if it's signed by one of these keys. Leaving this list empty turns off signature verification entirely, so any commit on `remote.branch` deploys unattended — only do that for testing.";
    };

    retry = {
      maxAttempts = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "How many consecutive failed switch attempts on the same commit to allow before giving up on it until a new commit is pushed. Retries happen at the `pollPeriod` cadence.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.repoPath != "";
        message = "ft.gitops.enable requires ft.gitops.repoPath to be set.";
      }
    ];

    warnings =
      lib.optional (cfg.signingKeys == [ ])
        "ft.gitops.signingKeys is empty: this daemon will switch to unsigned commits unattended. Set signingKeys to a list of trusted GPG public keys.";

    home.packages = lib.mkDefault [
      pkgs.home-manager
      pkgs.git
    ];

    systemd.user.services.ft-gitops = {
      Unit = {
        Description = "Pull-based GitOps for standalone Home Manager (ft.gitops)";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "exec";
        ExecStart = lib.mkDefault "${daemonScript}";
        Restart = lib.mkDefault "on-failure";
        RestartSec = lib.mkDefault "30s";
      };
      Install.WantedBy = lib.mkDefault [ "default.target" ];
    };
  };
}
