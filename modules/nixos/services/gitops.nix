{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:

# -----------------------------------------------------------------------------
#  ft.gitops — comin pull-based GitOps deployment
# -----------------------------------------------------------------------------
# Thin wrapper over comin (github:nlewo/comin). comin runs as a daemon that
# polls the configured git remotes and deploys this machine's own
# nixosConfiguration on new commits:
#
#   * deployBranch (e.g. main) -> `switch` (permanent), and
#   * comin's per-host `testing-<hostname>` branch -> `test` (ephemeral; a
#     reboot reverts it). This is the "try it on one box, then promote" lane and
#     maps onto the framework's feature -> testing -> main flow.
#
# Multiple remotes are polled together as failover (anti-SPOF): list the primary
# (e.g. self-hosted Forgejo) first and backups (e.g. Codeberg) after. Signature
# verification (signingKeys) applies to whichever remote answers, so failover is
# about availability, not trust.
#
# Per-remote credentials are read from sops; URLs and tokens stay in the
# consumer/sops, never in the framework.
let
  cfg = config.ft.gitops;

  hasToken = r: r.tokenSecret != null;
  tokenRemotes = builtins.filter hasToken cfg.remotes;

  # Map an ft.gitops remote onto a comin remote. Token auth is only wired when
  # sops is enabled; the assertion below turns the unsupported combination
  # (token without ft.sops) into a clear error rather than an eval failure.
  mkRemote =
    r:
    {
      inherit (r) name url;
      branches.main.name = cfg.deployBranch;
      poller.period = cfg.pollPeriod;
    }
    // lib.optionalAttrs (hasToken r && config.ft.sops.enable) {
      auth.access_token_path = config.sops.secrets.${r.tokenSecret}.path;
    };

  # comin deliberately deploys into its own isolated profile
  # (/nix/var/nix/profiles/system-profiles/comin), never touching
  # /nix/var/nix/profiles/system — the profile the bootloader actually reads
  # as the default boot entry. That's on purpose (a bad automated deploy can
  # never silently become the reboot default), but it means every successful
  # switch shows up as a separate "comin" submenu entry in the bootloader and
  # never becomes the thing that boots by default on its own. This hook runs
  # after every deployment via comin's own postDeploymentCommand and, only for
  # successful deploys of deployBranch specifically (never the ephemeral
  # per-host test branch, which must stay revertible on reboot), promotes
  # comin's profile into the main one and re-registers the bootloader default
  # — trading comin's safety net for the convenience of not needing a manual
  # `nixos-rebuild switch` after every automated deploy.
  autoPromoteScript = pkgs.writeShellScript "ft-gitops-auto-promote" ''
    set -euo pipefail

    if [ "$COMIN_STATUS" != "done" ]; then
      exit 0
    fi

    # COMIN_GIT_REF is "<remoteName>/<branchName>" - compare only the branch
    # portion, since the remote name varies across failover remotes.
    if [ "''${COMIN_GIT_REF##*/}" != "${cfg.deployBranch}" ]; then
      exit 0
    fi

    outPath=$(${pkgs.coreutils}/bin/readlink -f /nix/var/nix/profiles/system-profiles/comin)
    ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set "$outPath"
    "$outPath"/bin/switch-to-configuration boot
  '';

  # comin never retries an eval, build, or deployment failure on its own — it
  # only reprocesses a commit when a *new* commit arrives (its in-memory "last
  # seen commit" only resets on process start). This watchdog polls comin's own
  # Prometheus exporter for a failure and restarts comin.service to force it to
  # reprocess the current commit, up to retry.maxAttempts times before giving up
  # until a new commit is pushed.
  retryWatchdogScript = pkgs.writeShellScript "ft-gitops-retry-watchdog" ''
    set -euo pipefail

    metrics=$(${pkgs.curl}/bin/curl -fsS "http://127.0.0.1:${toString config.services.comin.exporter.port}/metrics") || {
      echo "ft-gitops-retry-watchdog: could not reach comin's exporter, skipping this check"
      exit 0
    }

    failed=0
    for metric in comin_last_eval_failed comin_last_build_failed comin_last_deployment_failed; do
      if ${pkgs.gnugrep}/bin/grep -qE "^''${metric} 1(\.0)?$" <<<"$metrics"; then
        failed=1
      fi
    done

    state="$STATE_DIRECTORY/attempts"
    attempts=0
    if [[ -f "$state" ]]; then
      attempts=$(<"$state")
    fi

    if [[ "$failed" -eq 1 ]]; then
      if [[ "$attempts" -lt ${toString cfg.retry.maxAttempts} ]]; then
        attempts=$((attempts + 1))
        echo "$attempts" > "$state"
        echo "ft-gitops-retry-watchdog: comin reported a failure (attempt $attempts/${toString cfg.retry.maxAttempts}), restarting comin.service"
        ${pkgs.systemd}/bin/systemctl restart comin.service
      else
        echo "ft-gitops-retry-watchdog: still failing after ${toString cfg.retry.maxAttempts} attempts, giving up until a new commit is pushed"
      fi
    else
      echo 0 > "$state"
    fi
  '';
in
{
  imports = [ inputs.comin.nixosModules.comin ];

  options.ft.gitops = {
    enable = lib.mkEnableOption "comin pull-based GitOps deployment" // {
      description = "Runs comin, a daemon that watches your git remotes and automatically deploys this machine's own configuration whenever new commits land: pushes to `deployBranch` are applied permanently with `switch`, while comin's per-host `testing-<hostname>` branch is applied only temporarily with `test` (a reboot reverts it). You can list multiple remotes and comin polls all of them, so no single remote being down stops deployments.";
    };

    remotes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "A short name for this remote (comin's remotes[].name).";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "The git URL comin polls (comin's remotes[].url). List your primary remote first (e.g. a self-hosted Forgejo instance) and any backups after (e.g. Codeberg) — comin polls all of them so no single remote is a point of failure.";
            };
            tokenSecret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Name of a sops secret holding an access token for this remote. When set, the secret is decrypted and wired into comin's auth.access_token_path; leave it null to poll the remote anonymously (for a public repository). Requires ft.sops.enable.";
            };
          };
        }
      );
      default = [ ];
      description = "Ordered list of git remotes comin polls for this machine's configuration. All of them are polled together so no single remote is a point of failure — list the primary one first.";
    };

    deployBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "The branch comin deploys permanently with `switch` (comin's remotes[].branches.main.name). This should track your production branch; when `signingKeys` is non-empty, commits on it must be signed by one of those keys.";
    };

    pollPeriod = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "How often, in seconds, comin checks each remote for new commits (comin's remotes[].poller.period).";
    };

    signingKeys = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Paths to armored GPG public key files; comin only deploys a commit if it's signed by one of these (comin's gpgPublicKeyPaths). Leaving this empty disables signature checking, meaning any commit pushed to a polled branch deploys automatically — strongly discouraged outside of testing.";
    };

    retry = {
      enable =
        lib.mkEnableOption "automatic retry of failed comin evaluations, builds, and deployments"
        // {
          description = "Runs a watchdog timer that checks comin's Prometheus exporter for a failed evaluation, build, or deployment, and restarts comin.service to make it retry the current commit — up to retry.maxAttempts times before giving up until a new commit is pushed.";
        };

      maxAttempts = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "How many times the watchdog restarts comin.service to try to recover from a failing commit, before giving up on it until a new commit arrives.";
      };

      checkInterval = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "How often, in seconds, the watchdog checks comin's exporter for a failure. Should comfortably exceed how long a typical evaluation, build, and switch takes, so it doesn't restart comin in the middle of an attempt.";
      };
    };

    autoPromote.enable =
      lib.mkEnableOption "promoting successful comin switch deployments to the bootloader default"
      // {
        description = "comin deliberately never touches /nix/var/nix/profiles/system - the profile the bootloader treats as the actual default - it always deploys into its own separate system-profiles/comin profile, so a bad automated deploy can never quietly become what boots by default. Normally you'd need to manually pick the \"comin\" entry in the bootloader menu, or run `nixos-rebuild switch` yourself, to make a comin deployment the default. Turning this on adds a hook that does that automatically after every successful deployment of deployBranch (never comin's temporary per-host test branch, which needs to stay revertible on reboot) - trading away that safety net for convenience.";
      };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.remotes != [ ];
        message = "ft.gitops.enable requires at least one entry in ft.gitops.remotes.";
      }
      {
        assertion = tokenRemotes == [ ] || config.ft.sops.enable;
        message = "ft.gitops remotes with a tokenSecret require ft.sops.enable = true.";
      }
    ];

    warnings =
      lib.optional (cfg.signingKeys == [ ])
        "ft.gitops.signingKeys is empty: comin will deploy unsigned commits unattended. Set signingKeys to a list of trusted GPG public keys."
      ++ lib.optional cfg.autoPromote.enable "ft.gitops.autoPromote.enable is on: successful deployBranch deployments become the bootloader default automatically, with no human confirmation step.";

    # Declare a sops secret for each token-authenticated remote so comin's
    # access_token_path resolves to a decrypted credential at runtime.
    sops.secrets = lib.optionalAttrs config.ft.sops.enable (
      lib.listToAttrs (map (r: lib.nameValuePair r.tokenSecret { }) tokenRemotes)
    );

    services.comin = {
      enable = true;
      remotes = map mkRemote cfg.remotes;
      gpgPublicKeyPaths = cfg.signingKeys;
      postDeploymentCommand = lib.mkIf cfg.autoPromote.enable autoPromoteScript;
    };

    # Degraded/recovery path: when the self-hosted binary cache is unreachable or
    # lacks a path (e.g. an emergency fix pushed to the Codeberg fallback that no
    # Forgejo runner pre-built), build locally instead of failing.
    nix.settings.fallback = lib.mkDefault true;

    systemd.services.ft-gitops-retry-watchdog = lib.mkIf cfg.retry.enable {
      description = "Restart comin after an eval, build, or deployment failure (ft.gitops.retry)";
      after = [ "comin.service" ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "ft-gitops-retry-watchdog";
        ExecStart = "${retryWatchdogScript}";
      };
    };

    systemd.timers.ft-gitops-retry-watchdog = lib.mkIf cfg.retry.enable {
      description = "Periodically checks comin for a failure to retry (ft.gitops.retry)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.retry.checkInterval;
        OnUnitActiveSec = cfg.retry.checkInterval;
        Unit = "ft-gitops-retry-watchdog.service";
      };
    };
  };
}
