{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# MICROVM WITH ROOTFUL DOCKER COMPOSE
################################################################################

let
  cfg = config.ft.dockervm;
  tapId = "tap-${cfg.vmName}";
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
      description = "Name of the host's external network interface (e.g. eth0, wlan0, enp3s0). Required by networking.nat to add the MASQUERADE rule that gives the VM internet access.";
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
    # Provide cloud-hypervisor and related host binaries from the microvm overlay.
    nixpkgs.overlays = [ inputs.microvm.overlay ];

    # ── Host bridge (microvm0) ───────────────────────────────────────────────
    #
    # systemd-networkd manages the bridge and auto-attaches the TAP interface
    # when microvm creates it at VM start.  Do not combine with networking.bridges
    # on the same interface — pick one manager.
    systemd.network.enable = lib.mkDefault true;

    systemd.network.netdevs."10-microvm0" = lib.mkDefault {
      netdevConfig = {
        Kind = "bridge";
        Name = "microvm0";
      };
    };

    systemd.network.networks."10-microvm0" = lib.mkDefault {
      matchConfig.Name = "microvm0";
      networkConfig = {
        Address = "${cfg.hostAddress}/${toString cfg.prefixLength}";
        ConfigureWithoutCarrier = true;
        IPv4Forwarding = true;
      };
      linkConfig.RequiredForOnline = "no";
    };

    # Attach the TAP interface (created by microvm at VM start) to the bridge.
    systemd.network.networks."10-${tapId}" = lib.mkDefault {
      matchConfig.Name = tapId;
      networkConfig.Bridge = "microvm0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    # ── NAT — guest internet access ──────────────────────────────────────────
    networking.nat = {
      enable = lib.mkDefault true;
      externalInterface = lib.mkDefault cfg.hostInterface;
      internalInterfaces = [ "microvm0" ];
    };

    # ── Persistent storage directories on the host ───────────────────────────
    systemd.tmpfiles.rules =
      # microvm@.service runs as the microvm user created by the host module.
      [ "d /var/lib/microvm/${cfg.vmName} 0750 microvm - -" ]
      ++ lib.optionals cfg.komodo.enable [
        "d /opt/komodo 0750 root root -"
        "d /opt/komodo/backups 0750 root root -"
      ];

    # ── VM definition ────────────────────────────────────────────────────────
    microvm.vms.${cfg.vmName} = {
      autostart = lib.mkDefault true;

      config =
        { pkgs, ... }:
        let
          komodoCompose = pkgs.writeText "komodo-compose.yaml" ''
            services:
              postgres:
                image: ghcr.io/ferretdb/postgres-documentdb
                labels:
                  komodo.skip:
                restart: unless-stopped
                volumes:
                  - postgres-data:/var/lib/postgresql/data
                environment:
                  POSTGRES_USER: ${cfg.komodo.dbUsername}
                  POSTGRES_PASSWORD: ${cfg.komodo.dbPassword}
                  POSTGRES_DB: postgres
                healthcheck:
                  test: ["CMD-SHELL", "pg_isready -U ${cfg.komodo.dbUsername}"]
                  interval: 5s
                  timeout: 5s
                  retries: 30
                  start_period: 10s

              ferretdb:
                image: ghcr.io/ferretdb/ferretdb
                labels:
                  komodo.skip:
                restart: unless-stopped
                depends_on:
                  postgres:
                    condition: service_healthy
                volumes:
                  - ferretdb-state:/state
                environment:
                  FERRETDB_POSTGRESQL_URL: postgres://${cfg.komodo.dbUsername}:${cfg.komodo.dbPassword}@postgres:5432/postgres

              core:
                image: ghcr.io/moghtech/komodo-core:${cfg.komodo.imageTag}
                init: true
                restart: unless-stopped
                depends_on:
                  - ferretdb
                ports:
                  - 9120:9120
                env_file: ./compose.env
                environment:
                  KOMODO_DATABASE_ADDRESS: ferretdb:27017
                volumes:
                  - keys:/config/keys
                  - /opt/komodo/backups:/backups

              periphery:
                image: ghcr.io/moghtech/komodo-periphery:${cfg.komodo.imageTag}
                init: true
                restart: unless-stopped
                depends_on:
                  - core
                env_file: ./compose.env
                volumes:
                  - keys:/config/keys
                  - /var/run/docker.sock:/var/run/docker.sock
                  - /proc:/proc
                  - /etc/komodo:/etc/komodo

            volumes:
              postgres-data:
              ferretdb-state:
              keys:
          '';

          komodoEnv = pkgs.writeText "komodo-compose.env" ''
            COMPOSE_KOMODO_IMAGE_TAG=${cfg.komodo.imageTag}
            COMPOSE_KOMODO_BACKUPS_PATH=/opt/komodo/backups

            KOMODO_DATABASE_USERNAME=${cfg.komodo.dbUsername}
            KOMODO_DATABASE_PASSWORD=${cfg.komodo.dbPassword}

            TZ=${cfg.komodo.timezone}

            KOMODO_HOST=${cfg.komodo.host}
            KOMODO_TITLE=Komodo
            KOMODO_PERIPHERY_PUBLIC_KEY=file:/config/keys/periphery.pub
            KOMODO_LOCAL_AUTH=true
            KOMODO_INIT_ADMIN_USERNAME=${cfg.komodo.adminUsername}
            KOMODO_INIT_ADMIN_PASSWORD=${cfg.komodo.adminPassword}
            KOMODO_FIRST_SERVER_NAME=${cfg.komodo.serverName}
            KOMODO_FIRST_SERVER=http://periphery:8120
            KOMODO_DISABLE_CONFIRM_DIALOG=false
            KOMODO_WEBHOOK_SECRET=${cfg.komodo.webhookSecret}
            KOMODO_JWT_SECRET=${cfg.komodo.jwtSecret}
            KOMODO_JWT_TTL=1-day
            KOMODO_MONITORING_INTERVAL=15-sec
            KOMODO_RESOURCE_POLL_INTERVAL=1-hr
            KOMODO_DISABLE_USER_REGISTRATION=false
            KOMODO_ENABLE_NEW_USERS=false
            KOMODO_DISABLE_NON_ADMIN_CREATE=false
            KOMODO_TRANSPARENT_MODE=false
            KOMODO_OIDC_ENABLED=false
            KOMODO_GITHUB_OAUTH_ENABLED=false
            KOMODO_GOOGLE_OAUTH_ENABLED=false
            KOMODO_AWS_ACCESS_KEY_ID=
            KOMODO_AWS_SECRET_ACCESS_KEY=
            KOMODO_LOGGING_PRETTY=false
            KOMODO_PRETTY_STARTUP_CONFIG=false

            PERIPHERY_CORE_ADDRESS=ws://core:9120
            PERIPHERY_CONNECT_AS=${cfg.komodo.serverName}
            PERIPHERY_CORE_PUBLIC_KEYS=file:/config/keys/core.pub
            PERIPHERY_ROOT_DIRECTORY=/etc/komodo
            PERIPHERY_DISABLE_TERMINALS=false
            PERIPHERY_DISABLE_CONTAINER_TERMINALS=false
            PERIPHERY_INCLUDE_DISK_MOUNTS=/etc/hostname
            PERIPHERY_LOGGING_PRETTY=false
            PERIPHERY_PRETTY_STARTUP_CONFIG=false
          '';
        in
        {
          microvm.hypervisor = lib.mkDefault "cloud-hypervisor";
          microvm.vcpu = lib.mkDefault cfg.vcpus;
          microvm.mem = lib.mkDefault cfg.mem;
          microvm.vsock.cid = lib.mkIf (cfg.vsockCid != null) (lib.mkDefault cfg.vsockCid);

          microvm.interfaces = lib.mkDefault [
            {
              type = "tap";
              id = tapId;
              mac = cfg.vmMac;
            }
          ];

          # Persistent Docker data lives on a host-side disk image so container
          # state survives VM restarts without requiring a full overlay2 rootfs.
          microvm.volumes = lib.mkDefault [
            {
              image = "/var/lib/microvm/${cfg.vmName}/docker.img";
              mountPoint = "/var/lib/docker";
              size = cfg.dockerVolumeSize;
            }
          ];

          # /opt/komodo shared from the host via virtiofs.
          microvm.shares = lib.mkIf cfg.komodo.enable (
            lib.mkDefault [
              {
                source = "/opt/komodo";
                mountPoint = "/opt/komodo";
                tag = "komodo";
                proto = "virtiofs";
              }
            ]
          );

          # ── Guest networking — static IP, gateway to host bridge ─────────
          systemd.network.enable = lib.mkDefault true;
          systemd.network.networks."10-eth" = lib.mkDefault {
            matchConfig.Name = "en* eth*";
            networkConfig = {
              Address = "${cfg.vmAddress}/${toString cfg.prefixLength}";
              Gateway = cfg.hostAddress;
              DNS = [
                "1.1.1.1"
                "8.8.8.8"
              ];
            };
          };

          # ── Rootful Docker with docker-compose ───────────────────────────
          virtualisation.docker.enable = lib.mkDefault true;
          virtualisation.docker.daemon.settings.storage-driver = lib.mkDefault "overlay2";

          environment.systemPackages = with pkgs; [ docker-compose ];

          # Working directory for compose projects.
          systemd.tmpfiles.rules = [ "d /opt/compose 0750 root root -" ];

          # ── Komodo stack ─────────────────────────────────────────────────
          systemd.services.komodo = lib.mkIf cfg.komodo.enable {
            description = "Komodo docker-compose stack";
            after = [
              "docker.service"
              "network-online.target"
              "opt-komodo.mount"
            ];
            requires = [ "opt-komodo.mount" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStartPre = [
                "${pkgs.coreutils}/bin/cp --no-clobber ${komodoCompose} /opt/komodo/compose.yaml"
                "${pkgs.coreutils}/bin/cp --no-clobber ${komodoEnv} /opt/komodo/compose.env"
              ];
              ExecStart = "${pkgs.docker-compose}/bin/docker-compose --env-file /opt/komodo/compose.env -f /opt/komodo/compose.yaml up -d --remove-orphans";
              ExecStop = "${pkgs.docker-compose}/bin/docker-compose --env-file /opt/komodo/compose.env -f /opt/komodo/compose.yaml down";
              StandardOutput = "append:/opt/komodo/komodo.log";
              StandardError = "append:/opt/komodo/komodo.log";
            };
          };

          services.openssh = lib.mkIf (cfg.sshAuthorizedKeys != [ ]) {
            enable = lib.mkDefault true;
            settings = {
              PermitRootLogin = lib.mkDefault "yes";
              PasswordAuthentication = lib.mkDefault false;
            };
          };

          users.users.root = lib.mkIf (cfg.sshAuthorizedKeys != [ ]) {
            openssh.authorizedKeys.keys = lib.mkDefault cfg.sshAuthorizedKeys;
          };

          networking.hostName = lib.mkDefault cfg.vmName;
          networking.firewall.enable = lib.mkDefault false;

          system.stateVersion = lib.mkDefault "25.05";
          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        };
    };
  };
}
