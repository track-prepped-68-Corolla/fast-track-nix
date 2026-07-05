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
      description = "Runs the comin daemon, which polls the configured git remotes and deploys this machine's own nixosConfiguration on new commits — `switch` (permanent) for `deployBranch`, `test` (ephemeral, reverted on reboot) for comin's per-host `testing-<hostname>` branch. Multiple remotes are polled as failover (anti-SPOF).";
    };

    remotes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Short identifier for this remote (comin remotes[].name).";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "Git URL comin polls (comin remotes[].url). List the primary first (e.g. self-hosted Forgejo) and backups after (e.g. Codeberg); comin polls all to avoid a single point of failure.";
            };
            tokenSecret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Name of a sops secret holding an access token for this remote. When set, the secret is declared and wired to comin's auth.access_token_path; null polls the remote anonymously (public repository). Requires ft.sops.enable.";
            };
          };
        }
      );
      default = [ ];
      description = "Ordered list of git remotes comin polls for this machine's configuration. Polled together as failover (anti-SPOF), primary first.";
    };

    deployBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch comin deploys permanently with `switch` (comin remotes[].branches.main.name). Tracks your production branch; commits must be signed by one of `signingKeys` when that list is non-empty.";
    };

    pollPeriod = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "How often, in seconds, comin polls each remote for new commits (comin remotes[].poller.period).";
    };

    signingKeys = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Armored GPG public key files; comin deploys a commit only if it is signed by one of these (comin gpgPublicKeyPaths). An empty list disables signature verification, letting any commit on a polled branch deploy unattended — strongly discouraged outside testing.";
    };

    retry = {
      enable =
        lib.mkEnableOption "automatic retry of failed comin evaluations, builds, and deployments"
        // {
          description = "Runs a watchdog timer that polls comin's Prometheus exporter for an eval, build, or deployment failure and restarts comin.service to force it to reprocess the current commit, up to retry.maxAttempts times before giving up until a new commit is pushed.";
        };

      maxAttempts = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Maximum number of times the watchdog restarts comin.service to recover the current failing commit before giving up on it until a new commit is pushed.";
      };

      checkInterval = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "How often, in seconds, the watchdog polls comin's exporter for a failure. Should comfortably exceed the time a typical evaluation, build, and switch takes, to avoid restarting comin mid-attempt.";
      };
    };

    autoPromote.enable =
      lib.mkEnableOption "promoting successful comin switch deployments to the bootloader default"
      // {
        description = "comin deliberately never updates /nix/var/nix/profiles/system (the profile the bootloader treats as the real default) - it always deploys into its own isolated system-profiles/comin profile, so a bad automated deploy can never silently become what boots by default. Normally a human must explicitly boot the \"comin\" bootloader submenu entry, or run a manual `nixos-rebuild switch`, to make a comin deployment the reboot default. Enabling this runs a postDeploymentCommand hook that does that automatically after every successful deployment of deployBranch specifically (never comin's ephemeral per-host test branch, which must stay revertible on reboot) - trading that safety net for convenience.";
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
      ++ lib.optional cfg.autoPromote.enable
        "ft.gitops.autoPromote.enable is on: successful deployBranch deployments become the bootloader default automatically, with no human confirmation step.";

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
