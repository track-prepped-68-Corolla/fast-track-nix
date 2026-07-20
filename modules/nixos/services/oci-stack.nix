{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# GUEST-SIDE OCI RUNTIME WITH DOCKER COMPOSE AND OPTIONAL KOMODO STACK
#
# Exempt from VM smoke tests: pulls container images from ghcr.io at runtime
# (binary cache-dependent). Test coverage is provided by the ft.dockervm
# integration which exercises the full stack end-to-end.
################################################################################

let
  cfg = config.ft.ociStack;

  # PERIPHERY_INCLUDE_DISK_MOUNTS line for the compose env file: rendered only
  # when the consumer lists mount points, otherwise omitted so Periphery falls
  # back to reporting every detected mount.
  peripheryDiskMountsLine = lib.optionalString (
    cfg.komodo.includeDiskMounts != [ ]
  ) "PERIPHERY_INCLUDE_DISK_MOUNTS=${lib.concatStringsSep "," cfg.komodo.includeDiskMounts}";

  # Optional extra bind mounts for Komodo Core's git working directories, appended
  # to the core service's volume list. Each is a full YAML list item at the sibling
  # indentation (6 spaces after the heredoc's 4-space dedent), rendered only when
  # the consumer sets a path.
  repoCacheVolume = lib.optionalString (
    cfg.komodo.repoCachePath != null
  ) "\n      - ${cfg.komodo.repoCachePath}:/repo-cache";
  syncVolume = lib.optionalString (
    cfg.komodo.syncPath != null
  ) "\n      - ${cfg.komodo.syncPath}:/syncs";
  coreGitVolumes = repoCacheVolume + syncVolume;

  # Optional Komodo [secrets] TOML files. Each is mounted read-only into its
  # container at a fixed .toml path (so Komodo picks the TOML parser) and loaded
  # via `--config-path`, which is the only way to supply a [secrets] section —
  # it cannot be set through environment variables. The values become
  # [[KEY]]-interpolatable into the Stacks/Deployments Komodo runs and are hidden
  # from the Komodo UI and logs. The source paths are provided by the wrapper
  # (e.g. ft.dockervm decrypts them with sops-nix inside the guest); this module
  # only mounts whatever path it is handed.
  coreSecretsTarget = "/run/komodo-secrets/core.toml";
  peripherySecretsTarget = "/run/komodo-secrets/periphery.toml";
  coreSecretsMount = lib.optionalString (
    cfg.komodo.coreSecretsFile != null
  ) "\n      - ${cfg.komodo.coreSecretsFile}:${coreSecretsTarget}:ro";
  peripherySecretsMount = lib.optionalString (
    cfg.komodo.peripherySecretsFile != null
  ) "\n      - ${cfg.komodo.peripherySecretsFile}:${peripherySecretsTarget}:ro";
  coreSecretsCommand = lib.optionalString (
    cfg.komodo.coreSecretsFile != null
  ) "\n    command: core --config-path ${coreSecretsTarget}";
  peripherySecretsCommand = lib.optionalString (
    cfg.komodo.peripherySecretsFile != null
  ) "\n    command: periphery --config-path ${peripherySecretsTarget}";

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
        env_file: ./compose.env${coreSecretsCommand}
        environment:
          KOMODO_DATABASE_ADDRESS: ferretdb:27017
        volumes:
          - keys:/config/keys
          - ${cfg.komodo.backupsPath}:/backups${coreGitVolumes}${coreSecretsMount}

      periphery:
        image: ghcr.io/moghtech/komodo-periphery:${cfg.komodo.imageTag}
        init: true
        restart: unless-stopped
        depends_on:
          - core
        env_file: ./compose.env${peripherySecretsCommand}
        volumes:
          - keys:/config/keys
          - /var/run/docker.sock:/var/run/docker.sock
          - /proc:/proc
          - ${cfg.komodo.peripheryRootDirectory}:${cfg.komodo.peripheryRootDirectory}${peripherySecretsMount}

    volumes:
      postgres-data:
      ferretdb-state:
      keys:
  '';

  komodoEnv = pkgs.writeText "komodo-compose.env" ''
    COMPOSE_KOMODO_IMAGE_TAG=${cfg.komodo.imageTag}
    COMPOSE_KOMODO_BACKUPS_PATH=${cfg.komodo.backupsPath}

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
    KOMODO_FIRST_SERVER=https://periphery:8120
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
    PERIPHERY_ROOT_DIRECTORY=${cfg.komodo.peripheryRootDirectory}
    PERIPHERY_DISABLE_TERMINALS=false
    PERIPHERY_DISABLE_CONTAINER_TERMINALS=false
    ${peripheryDiskMountsLine}
    PERIPHERY_LOGGING_PRETTY=false
    PERIPHERY_PRETTY_STARTUP_CONFIG=false
  '';

  runtimeService = if cfg.runtime == "podman" then "podman.service" else "docker.service";
in
{
  options.ft.ociStack = {
    enable =
      lib.mkEnableOption "OCI container runtime with docker-compose and optional Komodo stack"
      // {
        description = "Enables a rootful OCI container runtime (Docker or Podman) with docker-compose, and optionally deploys a Komodo core + periphery + FerretDB stack. Designed for use inside a microVM guest; provision the Docker data volume separately via ft.microvms.volumes.";
      };

    runtime = lib.mkOption {
      type = lib.types.enum [
        "docker"
        "podman"
      ];
      default = "docker";
      description = "OCI container runtime. Both options run rootful. With podman, Docker CLI compatibility and the Docker socket are enabled so that compose files using /var/run/docker.sock work unchanged.";
    };

    komodo = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Deploy a Komodo core + periphery + FerretDB stack via docker-compose. Container data is stored on the Docker volume; backups are written to komodo.backupsPath.";
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
        default = "http://localhost:9120";
        description = "Externally accessible URL for the Komodo Core instance; used for OAuth redirect URLs and webhook suggestions. Override with the VM's IP when deploying inside a microVM (e.g. http://10.0.100.2:9120).";
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "Local";
        description = "Name for the first Komodo server entry, and the name Periphery uses when connecting to Core.";
      };

      timezone = lib.mkOption {
        type = lib.types.str;
        default = "Etc/UTC";
        description = "Timezone for Komodo schedules (tz database name, e.g. America/New_York).";
      };

      backupsPath = lib.mkOption {
        type = lib.types.str;
        default = "/opt/komodo/backups";
        description = "Path inside the guest where Komodo writes backup archives. When using the ft.dockervm wrapper this is on a virtiofs share backed by the host.";
      };

      requireMountUnit = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Systemd mount unit that must be active before the Komodo service starts (e.g. opt-komodo.mount when backupsPath is on a virtiofs share). Set automatically by ft.dockervm; null disables the dependency.";
      };

      peripheryRootDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/etc/komodo";
        description = "Periphery's root directory inside the guest (PERIPHERY_ROOT_DIRECTORY), also bind-mounted into the periphery container at the same path. Every stack Periphery deploys and the source side of every bind mount it manages live under this directory. When using the ft.dockervm wrapper this is placed on a virtiofs share so the whole managed tree is browsable on the host.";
      };

      includeDiskMounts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Guest mount points Periphery reports disk usage for in the Komodo UI (PERIPHERY_INCLUDE_DISK_MOUNTS). An empty list omits the setting entirely so Periphery reports every detected mount; set specific paths (e.g. the Docker data root and virtiofs shares) to focus reporting on the mounts you care about.";
      };

      repoCachePath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Host-backed guest path bind-mounted into Komodo Core at /repo-cache, where it clones git repos for repo-based Stacks and Resource Syncs (Komodo's KOMODO_REPO_DIRECTORY default). null adds no mount, leaving the clones on the container's ephemeral layer. When using the ft.dockervm wrapper this is placed on a virtiofs share so clones persist across guest restarts and are browsable on the host.";
      };

      syncPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Host-backed guest path bind-mounted into Komodo Core at /syncs, used for 'Files on Server' Resource Syncs (Komodo's KOMODO_SYNC_DIRECTORY default). null adds no mount, leaving the files on the container's ephemeral layer. When using the ft.dockervm wrapper this is placed on a virtiofs share so sync files persist across guest restarts and are browsable on the host.";
      };

      coreSecretsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path inside the guest to a TOML file containing a [secrets] section, mounted read-only into the Komodo Core container and loaded via `core --config-path`. Its keys become globally [[KEY]]-interpolatable into every Stack/Deployment and are hidden from the Komodo UI and logs. null omits the mount. Supply the value of a sops-decrypted secret (e.g. ft.dockervm.komodo.coreSecrets wires this to /run/secrets/komodo/core_secrets in the guest); this module does not decrypt anything itself.";
      };

      peripherySecretsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path inside the guest to a TOML file containing a [secrets] section, mounted read-only into the Komodo Periphery container and loaded via `periphery --config-path`. Its keys become [[KEY]]-interpolatable into Stacks/Deployments that run on this Periphery only, never traverse the network, and are hidden from the Komodo UI and logs. null omits the mount. Supply the value of a sops-decrypted secret (e.g. ft.dockervm.komodo.peripherySecrets wires this to /run/secrets/komodo/periphery_secrets in the guest); this module does not decrypt anything itself.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = lib.mkIf (cfg.runtime == "docker") {
      enable = lib.mkDefault true;
      daemon.settings.storage-driver = lib.mkDefault "overlay2";
    };

    virtualisation.podman = lib.mkIf (cfg.runtime == "podman") {
      enable = lib.mkDefault true;
      dockerCompat = lib.mkDefault true;
      dockerSocket.enable = lib.mkDefault true;
    };

    environment.systemPackages = with pkgs; [ docker-compose ];

    systemd.tmpfiles.rules = [ "d /opt/compose 0750 root root -" ];

    systemd.services.komodo = lib.mkIf cfg.komodo.enable {
      description = "Komodo docker-compose stack";
      after = [
        runtimeService
        "network-online.target"
      ]
      ++ lib.optional (cfg.komodo.requireMountUnit != null) cfg.komodo.requireMountUnit;
      requires = lib.optional (cfg.komodo.requireMountUnit != null) cfg.komodo.requireMountUnit;
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
  };
}
