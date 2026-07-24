{
  config,
  options,
  lib,
  inputs,
  pkgs,
  ...
}:

################################################################################
# MICROVM WITH ROOTFUL DOCKER COMPOSE
#
# Thin wrapper that composes ft.microvms (host infrastructure) with the guest
# running ft.containers (rootful Docker + real docker-compose) and ft.komodo
# (Komodo compose stack), behind the existing ft.dockervm option interface.
################################################################################

let
  cfg = config.ft.dockervm;

  # Guest-side Komodo [secrets] injection: when either tier is enabled, sops-nix
  # runs inside the guest (decrypting on the guest's own persistent SSH host key),
  # var/secrets is shared in read-only, and the decrypted keys are consumed by
  # ft.komodo.secrets.{core,periphery} in the guest. See NOTES.md.
  komodoSecretsEnabled = cfg.komodo.peripherySecrets.enable || cfg.komodo.coreSecrets.enable;
  secretsShareSource = "${config.ft.repoPath}/var/secrets";

  # Host-side GitOps auto-apply: once the guest Core answers, reconcile Komodo
  # with containers/ by running the bundled `komodo-apply` recipe against Core's
  # API — the same justfile invocation the `ft` CLI wrapper uses. Runs as root
  # (to read the api_env secret) so it forces git safe.directory for the repo.
  scriptsDir = ../../../scripts;
  autoApplyScript = pkgs.writeShellScript "komodo-auto-apply" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.git
        pkgs.jq
        pkgs.curl
        pkgs.just
        pkgs.coreutils
      ]
    }:$PATH
    export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*'
    # Bounded wait for Komodo Core to come up before applying.
    for _ in $(seq 1 60); do
      if curl -sf -o /dev/null "${cfg.komodo.host}"; then break; fi
      sleep 5
    done
    exec just --shell ${pkgs.bash}/bin/bash \
      --justfile ${scriptsDir}/ft.just \
      --working-directory ${config.ft.repoPath} \
      komodo-apply
  '';
in
{
  # ft.dockervm uses a two-level name (like ft.cli, ft.keepass) because the
  # feature is a self-contained VM appliance rather than a generic service.
  # Cloud Hypervisor is the default hypervisor — it is lightweight like Firecracker
  # but supports virtiofs shares, which Firecracker does not.
  options.ft.dockervm = {
    enable = lib.mkEnableOption "microVM with rootful Docker Compose" // {
      description = "Boots a Cloud Hypervisor microVM attached to a host TAP bridge, installs rootful Docker and docker-compose inside the guest, and routes guest internet traffic via host NAT. Requires KVM (/dev/kvm) on the host and the microvm flake input (bundled with fast-track-nix).";
    };

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "docker-vm";
      description = "Name for the microvm instance. Used as the systemd service name, guest hostname, and TAP interface suffix (tap-<vmName>).";
    };

    vcpus = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Number of vCPUs assigned to the VM.";
    };

    mem = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = "Memory in MiB assigned to the VM.";
    };

    vmAddressSuffix = lib.mkOption {
      type = lib.types.ints.u8;
      default = 2;
      description = "Last octet of the VM's IP address on the shared microvm0 subnet (ft.microvms.hostAddress). Must be unique among all microvm instances on this host.";
    };

    dockerVolumeSize = lib.mkOption {
      type = lib.types.int;
      default = 20480;
      description = "Size of the persistent Docker data volume in MiB (image stored at /var/lib/microvm/<vmName>/docker.img on the host).";
    };

    vmMac = lib.mkOption {
      type = lib.types.str;
      default = "02:00:00:00:00:01";
      description = "MAC address assigned to the VM's TAP-backed network interface. Must be locally administered (first octet 02).";
    };

    vsockCid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "vsock context ID (CID) for the VM. When set, enables systemd-notify support for cloud-hypervisor and the host service will wait for the VM to signal readiness — do not set this if any service blocks multi-user.target for a long time (e.g. first-boot image pulls). Must be unique per host (valid range: 3–4294967293).";
    };

    hostInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Name of the host's external network interface (e.g. eth0, wlp3s0, enp3s0). Required by networking.nat to add the MASQUERADE rule that gives the VM internet access. Must be set when enable = true.";
    };

    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized to log in as root inside the VM. When non-empty, enables OpenSSH server in the guest on port 22 (the VM is only reachable from the host bridge, so exposure is limited to the host).";
    };

    komodo = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Deploy a Komodo instance (core + periphery + FerretDB) inside the VM. Container data is stored on the docker.img volume; backups are written to /opt/komodo/backups on the host via virtiofs.";
      };

      imageTag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Docker image tag for ghcr.io/moghtech/komodo-core and komodo-periphery.";
      };

      dbUsername = lib.mkOption {
        type = lib.types.str;
        default = "komodo";
        description = "Username for the FerretDB/Postgres database.";
      };

      dbPassword = lib.mkOption {
        type = lib.types.str;
        default = "komodo";
        description = "Password for the FerretDB/Postgres database. Stored in the Nix store — suitable only for local-only deployments.";
      };

      adminUsername = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Initial Komodo admin username created on first launch.";
      };

      adminPassword = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Initial Komodo admin password. Stored in the Nix store — change after first login.";
      };

      webhookSecret = lib.mkOption {
        type = lib.types.str;
        default = "komodo-webhook-secret";
        description = "Secret used to authenticate incoming Komodo webhooks. Stored in the Nix store.";
      };

      jwtSecret = lib.mkOption {
        type = lib.types.str;
        default = "komodo-jwt-secret";
        description = "Secret used to sign Komodo JWT tokens. Stored in the Nix store.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default =
          let
            subnetPrefix = lib.concatStringsSep "." (
              lib.take 3 (lib.splitString "." config.ft.microvms.hostAddress)
            );
          in
          "http://${subnetPrefix}.${toString cfg.vmAddressSuffix}:9120";
        description = "Public URL of the Komodo Core instance; used for OAuth redirect URLs and webhook suggestions.";
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "Local";
        description = "Name for the first Komodo server entry, and the name Periphery uses to connect to Core.";
      };

      timezone = lib.mkOption {
        type = lib.types.str;
        default = "Etc/UTC";
        description = "Timezone for Komodo schedules (tz database name, e.g. America/New_York).";
      };

      peripherySecrets.enable =
        lib.mkEnableOption "sops-decrypted Periphery [secrets] for the guest Komodo"
        // {
          description = "Runs sops-nix inside the guest to decrypt the komodo/periphery_secrets key from var/secrets/komodo.yaml (shared read-only into the guest) and loads it into Komodo Periphery via `--config-path`. Its keys become [[KEY]]-interpolatable into the Stacks this Periphery deploys, stay on the guest, and are hidden from the Komodo UI and logs. Adds a persistent volume for the guest's ed25519 SSH host key (the sops age recipient) and enables sshd so the recipient can be read via ssh-keyscan. Requires ft.repoPath and a one-time recipient bootstrap — see NOTES.md.";
        };

      coreSecrets.enable = lib.mkEnableOption "sops-decrypted Core [secrets] for the guest Komodo" // {
        description = "Like peripherySecrets, but decrypts komodo/core_secrets and loads it into Komodo Core as a global [secrets] file, [[KEY]]-interpolatable into every Stack/Deployment. Shares the same guest sops age identity and var/secrets share. Requires ft.repoPath and the guest recipient in .sops.yaml — see NOTES.md.";
      };

      autoApply.enable = lib.mkEnableOption "host-side Komodo GitOps auto-apply" // {
        description = "After the guest's Komodo Core answers, run the bundled `komodo-apply` recipe from the host (in ft.repoPath) to create/execute the ResourceSync over Komodo's API, so every rebuild reconciles Komodo with containers/ with no UI. Requires ft.cli, ft.sops and ft.repoPath, plus a `komodo/api_env` sops secret holding KOMODO_API_KEY and KOMODO_API_SECRET (create a Komodo API key once). See NOTES.md.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !komodoSecretsEnabled || config.ft.repoPath != options.ft.repoPath.default;
        message = "ft.dockervm.komodo.peripherySecrets/coreSecrets require ft.repoPath to point at your consumer repo so var/secrets/komodo.yaml can be shared into the guest — it is still the framework default (\"${options.ft.repoPath.default}\").";
      }
      {
        assertion =
          !cfg.komodo.autoApply.enable
          || (
            config.ft.cli.enable && config.ft.sops.enable && config.ft.repoPath != options.ft.repoPath.default
          );
        message = "ft.dockervm.komodo.autoApply requires ft.cli.enable, ft.sops.enable and ft.repoPath set to your consumer repo — it drives `ft komodo-apply` from the host and reads the komodo/api_env sops secret.";
      }
    ];

    # ── Host-side GitOps auto-apply ─────────────────────────────────────────
    sops.secrets = lib.mkIf cfg.komodo.autoApply.enable {
      # env-file: KOMODO_API_KEY=... and KOMODO_API_SECRET=... (create a Komodo
      # API key once and store it here). owner/mode default to root / 0400.
      "komodo/api_env" = { };
    };

    systemd.services.komodo-auto-apply = lib.mkIf cfg.komodo.autoApply.enable {
      description = "Reconcile Komodo with containers/ over the API (ft komodo-apply)";
      after = [
        "microvm@${cfg.vmName}.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = config.sops.secrets."komodo/api_env".path;
        Environment = [ "KOMODO_URL=${cfg.komodo.host}" ];
        ExecStart = "${autoApplyScript}";
      };
    };

    # ── Host-side Komodo directories (shared into the VM via virtiofs) ───────
    systemd.tmpfiles.rules = lib.optionals cfg.komodo.enable [
      "d /opt/komodo 0770 root container -"
      "d /opt/komodo/backups 0770 root container -"
      "d /opt/komodo/periphery 0770 root container -"
      "d /opt/komodo/repo-cache 0770 root container -"
      "d /opt/komodo/syncs 0770 root container -"
    ];

    # ── Infrastructure: delegate to ft.microvms ────────────────────
    ft.microvms.instances.${cfg.vmName} = {
      enable = lib.mkDefault true;
      inherit (cfg)
        vcpus
        mem
        vmAddressSuffix
        vmMac
        vsockCid
        hostInterface
        sshAuthorizedKeys
        ;

      volumes = [
        {
          image = "/var/lib/microvm/${cfg.vmName}/docker.img";
          mountPoint = "/var/lib/docker";
          size = cfg.dockerVolumeSize;
        }
      ]
      # Persist the guest's SSH host key so it is a stable sops age recipient
      # across guest restarts (mounted at /var/lib/ssh, not /etc/ssh, so the
      # NixOS-managed sshd_config is not shadowed).
      ++ lib.optional komodoSecretsEnabled {
        image = "/var/lib/microvm/${cfg.vmName}/sshkeys.img";
        mountPoint = "/var/lib/ssh";
        size = 16;
      };

      shares =
        lib.optionals cfg.komodo.enable [
          {
            source = "/opt/komodo";
            mountPoint = "/opt/komodo";
            tag = "komodo";
            proto = "virtiofs";
          }
        ]
        # Consumer's encrypted sops tree, read-only. The guest only holds a
        # recipient on var/secrets/komodo.yaml, so the other (host-recipient)
        # secrets in this directory remain undecryptable inside the guest.
        ++ lib.optional komodoSecretsEnabled {
          source = secretsShareSource;
          mountPoint = "/var/secrets";
          tag = "komodo-secrets";
          proto = "virtiofs";
        };

      # ── Application: inject ft.containers + ft.komodo into the guest ────────
      extraGuestConfig = {
        # sops-nix is imported unconditionally so the `sops` option is always
        # declared in the guest: a `sops = lib.mkIf komodoSecretsEnabled {...}`
        # definition below is only *suppressed* (not undeclared) by mkIf, so the
        # option must exist even when secrets are off, or evaluation fails with
        # "option microvm.vms.<name>.config.sops does not exist". With no secrets
        # defined, sops-nix is inert.
        imports = [
          ./containers.nix
          ./komodo.nix
          inputs.sops-nix.nixosModules.sops
        ];

        # Rootful Docker + the real docker-compose binary; ft.komodo reaches it
        # via ft.containers.socket.
        ft.containers = {
          enable = lib.mkDefault true;
          runtime = lib.mkDefault "docker";
          rootless = lib.mkDefault false;
        };

        ft.komodo = lib.mkIf cfg.komodo.enable {
          enable = lib.mkDefault true;
          # The guest configures sops-nix directly (below), not the framework
          # ft.sops module. ft.komodo no longer asserts against ft.sops, so
          # nothing special is needed here — sops-nix validates the keys.
          inherit (cfg.komodo)
            imageTag
            dbUsername
            dbPassword
            adminUsername
            adminPassword
            webhookSecret
            jwtSecret
            serverName
            timezone
            ;
          host = cfg.komodo.host;
          backupsPath = "/opt/komodo/backups";
          # Periphery's root directory lives on the /opt/komodo virtiofs share
          # (guest /opt/komodo → host /opt/komodo), so the managed tree is
          # browsable directly on the host under /opt/komodo/periphery.
          peripheryRootDirectory = "/opt/komodo/periphery";
          # Report disk usage for the guest's real data mounts in the Komodo UI.
          includeDiskMounts = [
            "/"
            "/var/lib/docker"
            "/opt/komodo"
          ];
          # Core's git working directories live on the /opt/komodo virtiofs share
          # so repo/sync clones persist across guest restarts and are browsable
          # on the host under /opt/komodo/{repo-cache,syncs}.
          repoCachePath = "/opt/komodo/repo-cache";
          syncPath = "/opt/komodo/syncs";
          # Guest sops-nix (below) decrypts komodo/{core,periphery}_secrets;
          # ft.komodo.secrets.* mounts them into Core/Periphery and loads them
          # via `--config-path`. Off (default) when the tier is disabled.
          secrets.core.enable = lib.mkDefault cfg.komodo.coreSecrets.enable;
          secrets.periphery.enable = lib.mkDefault cfg.komodo.peripherySecrets.enable;
        };

        # ft.komodo's compose oneshot must wait for the /opt/komodo virtiofs
        # share (its backups/periphery/repo-cache/syncs bind mounts live there).
        systemd.services.komodo = lib.mkIf cfg.komodo.enable {
          after = [ "opt-komodo.mount" ];
          requires = [ "opt-komodo.mount" ];
        };

        # ── Guest-side sops-nix ────────────────────────────────────────────────
        # Decrypts the Komodo [secrets] TOML on the guest's own persistent SSH
        # host key. var/secrets is shared in read-only at /var/secrets; only
        # komodo.yaml is encrypted to the guest recipient.
        sops = lib.mkIf komodoSecretsEnabled {
          defaultSopsFile = lib.mkDefault "/var/secrets/komodo.yaml";
          validateSopsFiles = lib.mkDefault false;
          age.sshKeyPaths = [ "/var/lib/ssh/ssh_host_ed25519_key" ];
          gnupg.sshKeyPaths = [ ];
          secrets =
            lib.optionalAttrs cfg.komodo.coreSecrets.enable { "komodo/core_secrets" = { }; }
            // lib.optionalAttrs cfg.komodo.peripherySecrets.enable { "komodo/periphery_secrets" = { }; };
        };

        # Persist the guest's ed25519 host key on the sshkeys volume so it stays a
        # stable age recipient. sshd generates it on first boot and serves the
        # public key to `ssh-keyscan` for the one-time recipient bootstrap.
        services.openssh = lib.mkIf komodoSecretsEnabled {
          enable = lib.mkDefault true;
          # List option left unwrapped so consumer-defined host keys merge.
          hostKeys = [
            {
              path = "/var/lib/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
          settings.PasswordAuthentication = lib.mkDefault false;
        };
      };
    };
  };
}
