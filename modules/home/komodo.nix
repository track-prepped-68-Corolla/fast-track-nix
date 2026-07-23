{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# KOMODO CORE + PERIPHERY + FERRETDB (Home Manager / user-level, docker-compose)
#
# The per-user counterpart of the NixOS ft.komodo module. Deploys the same
# upstream Komodo compose stack via the genuine docker-compose binary, driven
# through the user runtime's socket (ft.containers.socket). Requires the
# user-level ft.containers with compose.enable and ft.sops for the optional
# [secrets] tiers.
#
# Exempt from VM smoke tests: pulls container images from ghcr.io at runtime.
################################################################################

let
  cfg = config.ft.komodo;
  cCfg = config.ft.containers;

  docker-compose = lib.getExe pkgs.docker-compose;

  # Socket path is resolved at runtime from XDG_RUNTIME_DIR (KOMODO_DOCKER_SOCK
  # in the unit Environment, expanded from the systemd %t specifier) and injected
  # into the compose file via docker-compose's ${VAR} interpolation — %t itself
  # is not understood inside compose YAML.
  coreSecretsTarget = "/run/komodo-secrets/core.toml";
  peripherySecretsTarget = "/run/komodo-secrets/periphery.toml";
  coreSecretsMount = lib.optionalString cfg.secrets.core.enable "\n      - ${
    config.sops.secrets."komodo/core_secrets".path
  }:${coreSecretsTarget}:ro";
  peripherySecretsMount = lib.optionalString cfg.secrets.periphery.enable "\n      - ${
    config.sops.secrets."komodo/periphery_secrets".path
  }:${peripherySecretsTarget}:ro";
  coreSecretsCommand = lib.optionalString cfg.secrets.core.enable "\n    command: core --config-path ${coreSecretsTarget}";
  peripherySecretsCommand = lib.optionalString cfg.secrets.periphery.enable "\n    command: periphery --config-path ${peripherySecretsTarget}";

  peripheryDiskMountsLine = lib.optionalString (
    cfg.includeDiskMounts != [ ]
  ) "PERIPHERY_INCLUDE_DISK_MOUNTS=${lib.concatStringsSep "," cfg.includeDiskMounts}";

  repoCacheVolume = lib.optionalString (cfg.repoCachePath != null) "\n      - ${cfg.repoCachePath}:/repo-cache";
  syncVolume = lib.optionalString (cfg.syncPath != null) "\n      - ${cfg.syncPath}:/syncs";
  coreGitVolumes = repoCacheVolume + syncVolume;

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
          POSTGRES_USER: ${cfg.dbUsername}
          POSTGRES_PASSWORD: ${cfg.dbPassword}
          POSTGRES_DB: postgres
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U ${cfg.dbUsername}"]
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
          FERRETDB_POSTGRESQL_URL: postgres://${cfg.dbUsername}:${cfg.dbPassword}@postgres:5432/postgres

      core:
        image: ghcr.io/moghtech/komodo-core:${cfg.imageTag}
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
          - ${cfg.backupsPath}:/backups${coreGitVolumes}${coreSecretsMount}

      periphery:
        image: ghcr.io/moghtech/komodo-periphery:${cfg.imageTag}
        init: true
        restart: unless-stopped
        depends_on:
          - core
        env_file: ./compose.env${peripherySecretsCommand}
        volumes:
          - keys:/config/keys
          - ''${KOMODO_DOCKER_SOCK}:/var/run/docker.sock
          - /proc:/proc
          - ${cfg.peripheryRootDirectory}:${cfg.peripheryRootDirectory}${peripherySecretsMount}

    volumes:
      postgres-data:
      ferretdb-state:
      keys:
  '';

  komodoEnv = pkgs.writeText "komodo-compose.env" ''
    COMPOSE_KOMODO_IMAGE_TAG=${cfg.imageTag}
    COMPOSE_KOMODO_BACKUPS_PATH=${cfg.backupsPath}

    KOMODO_DATABASE_USERNAME=${cfg.dbUsername}
    KOMODO_DATABASE_PASSWORD=${cfg.dbPassword}

    TZ=${cfg.timezone}

    KOMODO_HOST=${cfg.host}
    KOMODO_TITLE=Komodo
    KOMODO_PERIPHERY_PUBLIC_KEY=file:/config/keys/periphery.pub
    KOMODO_LOCAL_AUTH=true
    KOMODO_INIT_ADMIN_USERNAME=${cfg.adminUsername}
    KOMODO_INIT_ADMIN_PASSWORD=${cfg.adminPassword}
    KOMODO_FIRST_SERVER_NAME=${cfg.serverName}
    KOMODO_FIRST_SERVER=https://periphery:8120
    KOMODO_DISABLE_CONFIRM_DIALOG=false
    KOMODO_WEBHOOK_SECRET=${cfg.webhookSecret}
    KOMODO_JWT_SECRET=${cfg.jwtSecret}
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
    PERIPHERY_CONNECT_AS=${cfg.serverName}
    PERIPHERY_CORE_PUBLIC_KEYS=file:/config/keys/core.pub
    PERIPHERY_ROOT_DIRECTORY=${cfg.peripheryRootDirectory}
    PERIPHERY_DISABLE_TERMINALS=false
    PERIPHERY_DISABLE_CONTAINER_TERMINALS=false
    ${peripheryDiskMountsLine}
    PERIPHERY_LOGGING_PRETTY=false
    PERIPHERY_PRETTY_STARTUP_CONFIG=false
  '';
in
{
  options.ft.komodo = {
    enable = lib.mkEnableOption "Komodo Core + Periphery + FerretDB (user-level)" // {
      description = "Deploys the upstream Komodo compose stack (Core, Periphery, FerretDB/Postgres) as a user-level docker-compose service on top of the Home Manager ft.containers. Requires ft.containers.enable with compose.enable and ft.sops.enable. Exempt from VM smoke tests: pulls images from ghcr.io at runtime.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/komodo";
      description = "Base directory for the Komodo compose project (compose files, logs) and the default backups/periphery trees.";
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
      description = "Externally accessible URL for the Komodo Core instance; used for OAuth redirect URLs and webhook suggestions.";
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
      default = "${config.xdg.dataHome}/komodo/backups";
      description = "Path where Komodo Core writes backup archives, bind-mounted into the Core container at /backups.";
    };

    peripheryRootDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/komodo/periphery";
      description = "Periphery's root directory (PERIPHERY_ROOT_DIRECTORY), bind-mounted into the periphery container at the same path. Every stack Periphery deploys and the source side of every bind mount it manages live under this directory.";
    };

    includeDiskMounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Mount points Periphery reports disk usage for in the Komodo UI (PERIPHERY_INCLUDE_DISK_MOUNTS). An empty list omits the setting so Periphery reports every detected mount.";
    };

    repoCachePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path bind-mounted into Komodo Core at /repo-cache, where it clones git repos for repo-based Stacks and Resource Syncs. null leaves the clones on the container's ephemeral layer.";
    };

    syncPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path bind-mounted into Komodo Core at /syncs, used for 'Files on Server' Resource Syncs. null leaves the files on the container's ephemeral layer.";
    };

    secrets = {
      periphery.enable = lib.mkEnableOption "sops-decrypted Periphery [secrets]" // {
        description = "Declares the komodo/periphery_secrets user sops key, mounts it read-only into the Periphery container, and loads it via `periphery --config-path`. Its keys become [[KEY]]-interpolatable into the Stacks this Periphery deploys and are hidden from the Komodo UI and logs. Requires ft.sops.enable.";
      };
      core.enable = lib.mkEnableOption "sops-decrypted Core [secrets]" // {
        description = "Declares the komodo/core_secrets user sops key, mounts it read-only into the Core container, and loads it via `core --config-path`. Its keys become globally [[KEY]]-interpolatable into every Stack/Deployment. Requires ft.sops.enable.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cCfg.enable && cCfg.compose.enable;
        message = "ft.komodo requires ft.containers.enable with ft.containers.compose.enable = true (it deploys via docker-compose).";
      }
      {
        assertion = config.ft.sops.enable;
        message = "ft.komodo requires ft.sops.enable = true.";
      }
    ];

    sops.secrets =
      lib.optionalAttrs cfg.secrets.core.enable { "komodo/core_secrets" = { }; }
      // lib.optionalAttrs cfg.secrets.periphery.enable { "komodo/periphery_secrets" = { }; };

    # Provision the compose project + data directories at activation.
    home.activation.komodoDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
        ${lib.escapeShellArg cfg.dataDir} \
        ${lib.escapeShellArg cfg.backupsPath} \
        ${lib.escapeShellArg cfg.peripheryRootDirectory}
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp --no-clobber ${komodoCompose} ${lib.escapeShellArg "${cfg.dataDir}/compose.yaml"}
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp --no-clobber ${komodoEnv} ${lib.escapeShellArg "${cfg.dataDir}/compose.env"}
    '';

    systemd.user.services.komodo = {
      Unit = {
        Description = "Komodo docker-compose stack";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [
          "DOCKER_HOST=unix://${cCfg.socket}"
          "KOMODO_DOCKER_SOCK=${cCfg.socket}"
        ];
        ExecStart = "${docker-compose} --project-directory ${cfg.dataDir} --env-file ${cfg.dataDir}/compose.env -f ${cfg.dataDir}/compose.yaml up -d --remove-orphans";
        ExecStop = "${docker-compose} --project-directory ${cfg.dataDir} --env-file ${cfg.dataDir}/compose.env -f ${cfg.dataDir}/compose.yaml down";
      };
      Install.WantedBy = lib.mkDefault [ "default.target" ];
    };
  };
}
