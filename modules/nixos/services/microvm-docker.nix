{
  config,
  lib,
  ...
}:

################################################################################
# MICROVM WITH ROOTFUL DOCKER COMPOSE
#
# Thin wrapper that composes ft.microvms (host infrastructure) with
# ft.ociStack (guest OCI runtime + Komodo) behind the existing
# ft.dockervm option interface.
################################################################################

let
  cfg = config.ft.dockervm;
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

    hostAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.100.1";
      description = "IP address of the host-side bridge interface (microvm0); becomes the VM's default gateway.";
    };

    vmAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.0.100.2";
      description = "Static IP address assigned to the VM's primary network interface.";
    };

    prefixLength = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Subnet prefix length shared by the host bridge and VM interface (e.g. 24 for /24).";
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
        default = "http://${cfg.vmAddress}:9120";
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
    };
  };

  config = lib.mkIf cfg.enable {
    # ── Host-side Komodo directories (shared into the VM via virtiofs) ───────
    systemd.tmpfiles.rules = lib.optionals cfg.komodo.enable [
      "d /opt/komodo 0770 root container -"
      "d /opt/komodo/backups 0770 root container -"
    ];

    # ── Infrastructure: delegate to ft.microvms ────────────────────
    ft.microvms.${cfg.vmName} = {
      enable = lib.mkDefault true;
      inherit (cfg)
        vcpus
        mem
        hostAddress
        vmAddress
        prefixLength
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
      ];

      shares = lib.optionals cfg.komodo.enable [
        {
          source = "/opt/komodo";
          mountPoint = "/opt/komodo";
          tag = "komodo";
          proto = "virtiofs";
        }
      ];

      # ── Application: inject ft.ociStack into the guest ──────────
      extraGuestConfig = {
        imports = [ ./oci-stack.nix ];
        ft.ociStack = {
          enable = lib.mkDefault true;
          runtime = lib.mkDefault "docker";
          komodo = {
            inherit (cfg.komodo)
              enable
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
            requireMountUnit = lib.mkIf cfg.komodo.enable "opt-komodo.mount";
          };
        };
      };
    };
  };
}
