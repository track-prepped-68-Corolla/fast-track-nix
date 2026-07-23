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
# user-level ft.containers with compose.enable.
#
# Credentials handling mirrors the NixOS module: the sensitive vars live in a
# credentials env-file kept separate from the non-secret compose.env. With
# ft.komodo.sopsEnv.enable that file is a sops-decrypted secret (default key
# komodo/env) so credentials never touch the Nix store; otherwise the credential
# defaults are written to the store (local-only).
#
# Exempt from VM smoke tests: pulls container images from ghcr.io at runtime.
################################################################################

let
  cfg = config.ft.komodo;
  cCfg = config.ft.containers;

  docker-compose = lib.getExe pkgs.docker-compose;

  # Credentials env-file: sops-decrypted secret when sopsEnv is on, else the
  # store-baked defaults copied to dataDir at activation.
  credsPath =
    if cfg.sopsEnv.enable then
      config.sops.secrets.${cfg.sopsEnv.secretName}.path
    else
      "${cfg.dataDir}/creds.env";

  # The runtime socket is resolved at runtime from XDG_RUNTIME_DIR
  # (KOMODO_DOCKER_SOCK in the unit Environment, expanded from the systemd %t
  # specifier) and injected into the compose file via ${VAR} interpolation — %t
  # itself is not understood inside compose YAML.
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
          POSTGRES_PASSWORD: ''${KOMODO_DATABASE_PASSWORD}
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
          FERRETDB_POSTGRESQL_URL: postgres://${cfg.dbUsername}:''${KOMODO_DATABASE_PASSWORD}@postgres:5432/postgres

      core:
        image: ghcr.io/moghtech/komodo-core:${cfg.imageTag}
        init: true
        restart: unless-stopped
        depends_on:
          - ferretdb
        ports:
          - 9120:9120
        env_file:
          - ./compose.env
          - ${credsPath}${coreSecretsCommand}
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
        env_file:
          - ./compose.env
          - ${credsPath}${peripherySecretsCommand}
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

    TZ=${cfg.timezone}

    KOMODO_HOST=${cfg.host}
    KOMODO_TITLE=Komodo
    KOMODO_PERIPHERY_PUBLIC_KEY=file:/config/keys/periphery.pub
    KOMODO_LOCAL_AUTH=true
    KOMODO_INIT_ADMIN_USERNAME=${cfg.adminUsername}
    KOMODO_FIRST_SERVER_NAME=${cfg.serverName}
    KOMODO_FIRST_SERVER=https://periphery:8120
    KOMODO_DISABLE_CONFIRM_DIALOG=false
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

  # Store-baked credential defaults, used only when sopsEnv is disabled
  # (local-only). With sopsEnv on, the sops secret supplies these instead.
  credsEnv = pkgs.writeText "komodo-creds.env" ''
    KOMODO_DATABASE_PASSWORD=${cfg.dbPassword}
    KOMODO_INIT_ADMIN_PASSWORD=${cfg.adminPassword}
    KOMODO_WEBHOOK_SECRET=${cfg.webhookSecret}
    KOMODO_JWT_SECRET=${cfg.jwtSecret}
  '';
in
{
  options.ft.komodo = {
    enable = lib.mkEnableOption "Komodo Core + Periphery + FerretDB (user-level)" // {
      description = "Deploys the upstream Komodo compose stack (Core, Periphery, FerretDB/Postgres) as a user-level docker-compose service on top of the Home Manager ft.containers. Requires ft.containers.enable with compose.enable. Exempt from VM smoke tests: pulls images from ghcr.io at runtime.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/komodo";
      description = "Base directory for the Komodo compose project (compose files, credentials env-file, logs) and the default backups/periphery trees.";
    };

    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Docker image tag for ghcr.io/moghtech/komodo-core and komodo-periphery.";
    };

    dbUsername = lib.mkOption {
      type = lib.types.str;
      default = "komodo";
      description = "Username for the FerretDB/Postgres database (not a secret — baked into the compose config).";
    };

    dbPassword = lib.mkOption {
      type = lib.types.str;
      default = "komodo";
      description = "Default password for the FerretDB/Postgres database, used only when ft.komodo.sopsEnv.enable is false (written to the Nix store — local-only). With sopsEnv on, KOMODO_DATABASE_PASSWORD from the sops env-file overrides it.";
    };

    adminUsername = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Initial Komodo admin username created on first launch (not a secret).";
    };

    adminPassword = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Default initial Komodo admin password, used only when ft.komodo.sopsEnv.enable is false (written to the Nix store — local-only). With sopsEnv on, KOMODO_INIT_ADMIN_PASSWORD from the sops env-file overrides it.";
    };

    webhookSecret = lib.mkOption {
      type = lib.types.str;
      default = "komodo-webhook-secret";
      description = "Default secret for authenticating incoming Komodo webhooks, used only when ft.komodo.sopsEnv.enable is false (written to the Nix store). With sopsEnv on, KOMODO_WEBHOOK_SECRET from the sops env-file overrides it.";
    };

    jwtSecret = lib.mkOption {
      type = lib.types.str;
      default = "komodo-jwt-secret";
      description = "Default secret for signing Komodo JWT tokens, used only when ft.komodo.sopsEnv.enable is false (written to the Nix store). With sopsEnv on, KOMODO_JWT_SECRET from the sops env-file overrides it.";
    };

    sopsEnv = {
      enable = lib.mkEnableOption "sops-backed Komodo credentials env-file" // {
        description = "Sources the sensitive Komodo credentials (KOMODO_DATABASE_PASSWORD, KOMODO_INIT_ADMIN_PASSWORD, KOMODO_JWT_SECRET, KOMODO_WEBHOOK_SECRET) from a user-level sops-decrypted env-file (ft.komodo.sopsEnv.secretName) instead of the Nix store. Requires ft.sops.enable; populate the key as KEY=VALUE lines — see NOTES.md.";
      };

      secretName = lib.mkOption {
        type = lib.types.str;
        default = "komodo/env";
        description = "User sops secret key holding the Komodo credentials as an env-file (KEY=VALUE lines). Declared and decrypted when sopsEnv.enable is true.";
      };
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
        description = "Declares the komodo/periphery_secrets user sops key, mounts it read-only into the Periphery container, and loads it via `periphery --config-path`. Its keys become [[KEY]]-interpolatable into the Stacks this Periphery deploys and are hidden from the Komodo UI and logs. This is for interpolation into deployed Stacks — distinct from ft.komodo.sopsEnv, which covers Komodo's own credentials. Requires ft.sops.enable.";
      };
      core.enable = lib.mkEnableOption "sops-decrypted Core [secrets]" // {
        description = "Declares the komodo/core_secrets user sops key, mounts it read-only into the Core container, and loads it via `core --config-path`. Its keys become globally [[KEY]]-interpolatable into every Stack/Deployment. This is for interpolation into deployed Stacks — distinct from ft.komodo.sopsEnv, which covers Komodo's own credentials. Requires ft.sops.enable.";
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
        assertion =
          (cfg.sopsEnv.enable || cfg.secrets.core.enable || cfg.secrets.periphery.enable)
          -> config.ft.sops.enable;
        message = "ft.komodo.sopsEnv and ft.komodo.secrets.{core,periphery} require ft.sops.enable = true to decrypt their sops keys.";
      }
    ];

    sops.secrets =
      lib.optionalAttrs cfg.sopsEnv.enable { ${cfg.sopsEnv.secretName} = { }; }
      // lib.optionalAttrs cfg.secrets.core.enable { "komodo/core_secrets" = { }; }
      // lib.optionalAttrs cfg.secrets.periphery.enable { "komodo/periphery_secrets" = { }; };

    # Provision the compose project + data directories at activation, and stage
    # the store-baked credential defaults unless sops supplies them instead.
    home.activation.komodoDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      ''
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p \
          ${lib.escapeShellArg cfg.dataDir} \
          ${lib.escapeShellArg cfg.backupsPath} \
          ${lib.escapeShellArg cfg.peripheryRootDirectory}
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -f ${komodoCompose} ${lib.escapeShellArg "${cfg.dataDir}/compose.yaml"}
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -f ${komodoEnv} ${lib.escapeShellArg "${cfg.dataDir}/compose.env"}
      ''
      + lib.optionalString (!cfg.sopsEnv.enable) ''
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp --no-clobber ${credsEnv} ${lib.escapeShellArg "${cfg.dataDir}/creds.env"}
      ''
    );

    systemd.user.services.komodo = {
      Unit = {
        Description = "Komodo docker-compose stack";
        # The --user manager never reaches network-online.target, so the podman
        # runtime's user socket is the real readiness dependency; order + pull it
        # in when podman is the backend (docker's socket is managed outside HM).
        After = [
          "network-online.target"
        ]
        ++ lib.optional (cCfg.runtime == "podman") "podman.socket"
        ++ lib.optional cfg.sopsEnv.enable "sops-nix.service";
        Wants = lib.optional (cCfg.runtime == "podman") "podman.socket";
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [
          "DOCKER_HOST=unix://${cCfg.socket}"
          "KOMODO_DOCKER_SOCK=${cCfg.socket}"
        ];
        ExecStart = "${docker-compose} --project-directory ${cfg.dataDir} --env-file ${cfg.dataDir}/compose.env --env-file ${credsPath} -f ${cfg.dataDir}/compose.yaml up -d --remove-orphans";
        ExecStop = "${docker-compose} --project-directory ${cfg.dataDir} --env-file ${cfg.dataDir}/compose.env --env-file ${credsPath} -f ${cfg.dataDir}/compose.yaml down";
      };
      # List option left unwrapped so it merges rather than being replaced.
      Install.WantedBy = [ "default.target" ];
    };
  };
}
