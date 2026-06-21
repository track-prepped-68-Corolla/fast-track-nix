{
  lib,
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

    warnings = lib.optional (cfg.signingKeys == [ ]) "ft.gitops.signingKeys is empty: comin will deploy unsigned commits unattended. Set signingKeys to a list of trusted GPG public keys.";

    # Declare a sops secret for each token-authenticated remote so comin's
    # access_token_path resolves to a decrypted credential at runtime.
    sops.secrets = lib.optionalAttrs config.ft.sops.enable (
      lib.listToAttrs (map (r: lib.nameValuePair r.tokenSecret { }) tokenRemotes)
    );

    services.comin = {
      enable = true;
      remotes = map mkRemote cfg.remotes;
      gpgPublicKeyPaths = cfg.signingKeys;
    };

    # Degraded/recovery path: when the self-hosted binary cache is unreachable or
    # lacks a path (e.g. an emergency fix pushed to the Codeberg fallback that no
    # Forgejo runner pre-built), build locally instead of failing.
    nix.settings.fallback = lib.mkDefault true;
  };
}
