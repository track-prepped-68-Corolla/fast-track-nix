{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# KOMODO CORE + PERIPHERY (Home Manager / user-level)
################################################################################

let
  cfg = config.ft.home.komodo;
in
{
  options.ft.home.komodo = {
    enable = lib.mkEnableOption "Komodo Core and Periphery (user-level)" // {
      description = "Deploys Komodo Core, Periphery, and PostgreSQL as rootless Podman user services via systemd. Requires ft.security.sops.enable = true. Populate the sops secret keys documented in NOTES.md before first deploy.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/komodo";
      description = "Base directory for persistent Komodo container data (postgres, core).";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      podman = lib.getExe pkgs.podman;
      sleep = lib.getExe' pkgs.coreutils "sleep";

      postgresStart = pkgs.writeShellScript "podman-run-komodo-postgres" ''
        exec ${podman} run \
          --name=komodo-postgres \
          --env-file=${config.sops.secrets."komodo/postgres_env".path} \
          --volume=${cfg.dataDir}/postgres:/var/lib/postgresql/data \
          --network=komodo-net \
          --health-cmd='pg_isready -U komodo -d komodo' \
          --health-interval=5s \
          --health-timeout=3s \
          --health-retries=10 \
          --health-start-period=10s \
          docker.io/library/postgres:16
      '';

      coreStart = pkgs.writeShellScript "podman-run-komodo-core" ''
        exec ${podman} run \
          --name=komodo-core \
          --env-file=${config.sops.secrets."komodo/core_env".path} \
          --volume=${cfg.dataDir}/core:/data \
          --publish=9120:9120 \
          --network=komodo-net \
          ghcr.io/moghtech/komodo/core:latest
      '';

      peripheryStart = pkgs.writeShellScript "podman-run-komodo-periphery" ''
        exec ${podman} run \
          --name=komodo-periphery \
          --env-file=${config.sops.secrets."komodo/periphery_env".path} \
          --publish=8120:8120 \
          --network=komodo-net \
          ghcr.io/moghtech/komodo/periphery:latest
      '';

      createNet = pkgs.writeShellScript "create-komodo-net" ''
        ${podman} network inspect komodo-net >/dev/null 2>&1 \
          || ${podman} network create komodo-net
      '';

      # Polls podman healthcheck until postgres reports healthy before Core starts.
      waitForPostgres = pkgs.writeShellScript "wait-for-komodo-postgres" ''
        until ${podman} healthcheck run komodo-postgres 2>/dev/null; do
          ${sleep} 2
        done
      '';
    in
    {
      assertions = [
        {
          assertion = config.ft.security.sops.enable;
          message = "ft.home.komodo requires ft.security.sops.enable = true";
        }
      ];

      home.packages = lib.mkDefault [ pkgs.podman ];

      # User-level sops-nix env-file secrets (KEY=VALUE format) — see NOTES.md.
      sops.secrets = {
        "komodo/postgres_env" = { };
        "komodo/core_env" = { };
        "komodo/periphery_env" = { };
      };

      # Create persistent data directories at activation time.
      home.activation.createKomodoDataDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg "${cfg.dataDir}/postgres"} ${lib.escapeShellArg "${cfg.dataDir}/core"}
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod 0750 ${lib.escapeShellArg "${cfg.dataDir}/postgres"} ${lib.escapeShellArg "${cfg.dataDir}/core"}
      '';

      systemd.user.services = {
        # Create the komodo-net podman network before any container starts.
        podman-create-komodo-net = {
          Unit = {
            Description = "Create komodo-net Podman network";
            Before = [
              "podman-komodo-postgres.service"
              "podman-komodo-core.service"
              "podman-komodo-periphery.service"
            ];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = lib.mkDefault "${createNet}";
          };
          Install.WantedBy = lib.mkDefault [ "default.target" ];
        };

        podman-komodo-postgres = {
          Unit = {
            Description = "Komodo PostgreSQL container";
            After = [
              "network.target"
              "podman-create-komodo-net.service"
            ];
            Requires = [ "podman-create-komodo-net.service" ];
          };
          Service = {
            Type = "exec";
            ExecStartPre = lib.mkDefault "-${podman} rm -f komodo-postgres";
            ExecStart = lib.mkDefault "${postgresStart}";
            ExecStop = lib.mkDefault "${podman} stop komodo-postgres";
            Restart = lib.mkDefault "on-failure";
            RestartSec = lib.mkDefault "5s";
          };
          Install.WantedBy = lib.mkDefault [ "default.target" ];
        };

        podman-komodo-core = {
          Unit = {
            Description = "Komodo Core container";
            After = [
              "network.target"
              "podman-create-komodo-net.service"
              "podman-komodo-postgres.service"
            ];
            Requires = [
              "podman-create-komodo-net.service"
              "podman-komodo-postgres.service"
            ];
          };
          Service = {
            Type = "exec";
            # Remove any stale container first, then wait for postgres to be healthy.
            ExecStartPre = lib.mkDefault [
              "-${podman} rm -f komodo-core"
              "${waitForPostgres}"
            ];
            ExecStart = lib.mkDefault "${coreStart}";
            ExecStop = lib.mkDefault "${podman} stop komodo-core";
            Restart = lib.mkDefault "on-failure";
            RestartSec = lib.mkDefault "5s";
          };
          Install.WantedBy = lib.mkDefault [ "default.target" ];
        };

        podman-komodo-periphery = {
          Unit = {
            Description = "Komodo Periphery container";
            After = [
              "network.target"
              "podman-create-komodo-net.service"
              "podman-komodo-core.service"
            ];
            Requires = [
              "podman-create-komodo-net.service"
              "podman-komodo-core.service"
            ];
          };
          Service = {
            Type = "exec";
            ExecStartPre = lib.mkDefault "-${podman} rm -f komodo-periphery";
            ExecStart = lib.mkDefault "${peripheryStart}";
            ExecStop = lib.mkDefault "${podman} stop komodo-periphery";
            Restart = lib.mkDefault "on-failure";
            RestartSec = lib.mkDefault "5s";
          };
          Install.WantedBy = lib.mkDefault [ "default.target" ];
        };
      };
    }
  );
}
