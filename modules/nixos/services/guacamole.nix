{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# APACHE GUACAMOLE — CLIENTLESS REMOTE DESKTOP GATEWAY
#
# Deploys guacd, the Guacamole web app, and PostgreSQL as OCI containers on a
# dedicated guacamole-net network using virtualisation.oci-containers.
#
# Exempt from VM smoke tests: pulls container images from Docker Hub at runtime
# (binary cache-dependent). Same exemption class as ft.ociStack.
################################################################################

let
  cfg = config.ft.guacamole;
  rtSvc = "${cfg.runtime}.service";
  ctPrefix = cfg.runtime;
  rt = pkgs.${cfg.runtime};
in
{
  options.ft.guacamole = {
    enable = lib.mkEnableOption "Apache Guacamole remote desktop gateway" // {
      description = "Deploys Apache Guacamole (guacd, web front-end, and PostgreSQL) as OCI containers on a dedicated guacamole-net network. Requires an OCI runtime (Docker or Podman) already enabled on the host.";
    };

    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Image tag for guacamole/guacd and guacamole/guacamole on Docker Hub.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8084;
      description = "Host port mapped to the Guacamole web interface (container port 8080).";
    };

    dbName = lib.mkOption {
      type = lib.types.str;
      default = "guacamole_db";
      description = "PostgreSQL database name used by Guacamole.";
    };

    dbUsername = lib.mkOption {
      type = lib.types.str;
      default = "guacamole";
      description = "PostgreSQL username.";
    };

    dbPassword = lib.mkOption {
      type = lib.types.str;
      default = "guacamole";
      description = "PostgreSQL password. Stored in the Nix store — suitable only for local-only deployments. Use sops-nix or a similar secrets manager for production.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/opt/guacamole";
      description = "Base directory for Guacamole persistent data: PostgreSQL data, drive files, session recordings, and the generated initdb schema.";
    };

    runtime = lib.mkOption {
      type = lib.types.enum [
        "docker"
        "podman"
      ];
      default = "docker";
      description = "OCI container runtime backend. Must match virtualisation.oci-containers.backend when other modules also use oci-containers on the same host.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = lib.mkDefault cfg.runtime;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}          0750 root root -"
      "d ${cfg.dataDir}/initdb   0750 root root -"
      "d ${cfg.dataDir}/drive    0750 root root -"
      "d ${cfg.dataDir}/record   0750 root root -"
      "d ${cfg.dataDir}/postgres 0750 root root -"
    ];

    # Generate the PostgreSQL schema init script from the Guacamole image on
    # first run. Postgres loads it via /docker-entrypoint-initdb.d/ only when the
    # data directory is uninitialised, so subsequent service restarts are idempotent.
    systemd.services.guacamole-initdb = {
      description = "Generate Guacamole PostgreSQL schema init script";
      before = [ "${ctPrefix}-guacamole-postgres.service" ];
      wantedBy = [ "multi-user.target" ];
      after = [ rtSvc ];
      requires = [ rtSvc ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = lib.mkDefault true;
        ExecStart = lib.mkDefault (
          pkgs.writeShellScript "guacamole-initdb" ''
            set -euo pipefail
            if [ ! -s ${cfg.dataDir}/initdb/initdb.sql ]; then
              ${rt}/bin/${cfg.runtime} run --rm \
                guacamole/guacamole:${cfg.imageTag} \
                /opt/guacamole/bin/initdb.sh --postgresql \
                > ${cfg.dataDir}/initdb/initdb.sql
            fi
          ''
        );
      };
    };

    # Create the dedicated container network before any Guacamole containers start.
    systemd.services.guacamole-create-net = {
      description = "Create guacamole-net container network";
      before = [
        "${ctPrefix}-guacamole-postgres.service"
        "${ctPrefix}-guacamole-guacd.service"
        "${ctPrefix}-guacamole-web.service"
      ];
      wantedBy = [ "multi-user.target" ];
      after = [ rtSvc ];
      requires = [ rtSvc ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = lib.mkDefault true;
        ExecStart = lib.mkDefault (
          pkgs.writeShellScript "guacamole-create-net" ''
            ${rt}/bin/${cfg.runtime} network inspect guacamole-net >/dev/null 2>&1 || \
              ${rt}/bin/${cfg.runtime} network create guacamole-net
          ''
        );
      };
    };

    virtualisation.oci-containers.containers = {
      guacamole-postgres = {
        image = lib.mkDefault "docker.io/library/postgres:15";
        environment = lib.mkDefault {
          POSTGRES_DB = cfg.dbName;
          POSTGRES_USER = cfg.dbUsername;
          POSTGRES_PASSWORD = cfg.dbPassword;
        };
        volumes = lib.mkDefault [
          "${cfg.dataDir}/postgres:/var/lib/postgresql/data"
          "${cfg.dataDir}/initdb:/docker-entrypoint-initdb.d:ro"
        ];
        extraOptions = lib.mkDefault [
          "--network=guacamole-net"
          "--health-cmd=pg_isready -U ${cfg.dbUsername} -d ${cfg.dbName}"
          "--health-interval=5s"
          "--health-timeout=3s"
          "--health-retries=10"
          "--health-start-period=10s"
        ];
      };

      guacamole-guacd = {
        image = lib.mkDefault "guacamole/guacd:${cfg.imageTag}";
        volumes = lib.mkDefault [
          "${cfg.dataDir}/drive:/drive"
          "${cfg.dataDir}/record:/record"
        ];
        extraOptions = lib.mkDefault [ "--network=guacamole-net" ];
      };

      guacamole-web = {
        image = lib.mkDefault "guacamole/guacamole:${cfg.imageTag}";
        environment = lib.mkDefault {
          GUACD_HOSTNAME = "guacamole-guacd";
          POSTGRESQL_HOSTNAME = "guacamole-postgres";
          POSTGRESQL_DATABASE = cfg.dbName;
          POSTGRESQL_USER = cfg.dbUsername;
          POSTGRESQL_PASSWORD = cfg.dbPassword;
          POSTGRESQL_AUTO_CREATE_ACCOUNTS = "true";
        };
        ports = lib.mkDefault [ "${toString cfg.port}:8080" ];
        dependsOn = lib.mkDefault [
          "guacamole-postgres"
          "guacamole-guacd"
        ];
        extraOptions = lib.mkDefault [ "--network=guacamole-net" ];
      };
    };

    # Inject pre-flight ordering into the auto-generated container services.
    systemd.services = {
      "${ctPrefix}-guacamole-postgres" = {
        after = [
          "guacamole-initdb.service"
          "guacamole-create-net.service"
        ];
        requires = [ "guacamole-initdb.service" ];
      };
      "${ctPrefix}-guacamole-guacd".after = [ "guacamole-create-net.service" ];
      "${ctPrefix}-guacamole-web".after = [ "guacamole-create-net.service" ];
    };
  };
}
