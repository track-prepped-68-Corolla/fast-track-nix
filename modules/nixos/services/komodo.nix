{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# KOMODO CORE + PERIPHERY
################################################################################

let
  cfg = config.ft.komodo;
  podmanUid = config.ft."podman-rootless".uid;
  rtDir = "XDG_RUNTIME_DIR=/run/user/${toString podmanUid}";
  homeEnv = "HOME=/home/podman";
in
{
  meta.description = "Deploys Komodo Core, Periphery, and PostgreSQL as rootless Podman containers under the podman service user. Requires ft.\"podman-rootless\".enable = true. Populate the sops secret keys documented in NOTES.md before the first deploy.";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft."podman-rootless".enable;
        message = "ft.komodo requires ft.\"podman-rootless\".enable = true";
      }
    ];

    sops.secrets = {
      "komodo/postgres_env" = {
        owner = lib.mkDefault "podman";
        mode = lib.mkDefault "0440";
      };
      "komodo/core_env" = {
        owner = lib.mkDefault "podman";
        mode = lib.mkDefault "0440";
      };
      "komodo/periphery_env" = {
        owner = lib.mkDefault "podman";
        mode = lib.mkDefault "0440";
      };
    };

    systemd.tmpfiles.rules = [
      "d /opt/containers/komodo          0750 podman podman -"
      "d /opt/containers/komodo/postgres 0750 podman podman -"
      "d /opt/containers/komodo/core     0750 podman podman -"
    ];

    virtualisation.oci-containers = {
      backend = lib.mkDefault "podman";

      containers = {
        komodo-postgres = {
          image = lib.mkDefault "docker.io/library/postgres:16";
          environmentFiles = lib.mkDefault [ config.sops.secrets."komodo/postgres_env".path ];
          volumes = lib.mkDefault [ "/opt/containers/komodo/postgres:/var/lib/postgresql/data" ];
          extraOptions = lib.mkDefault [
            "--network=komodo-net"
            "--health-cmd=pg_isready -U komodo -d komodo"
            "--health-interval=5s"
            "--health-timeout=3s"
            "--health-retries=10"
            "--health-start-period=10s"
          ];
        };

        komodo-core = {
          image = lib.mkDefault "ghcr.io/moghtech/komodo/core:latest";
          environmentFiles = lib.mkDefault [ config.sops.secrets."komodo/core_env".path ];
          volumes = lib.mkDefault [ "/opt/containers/komodo/core:/data" ];
          ports = lib.mkDefault [ "9120:9120" ];
          dependsOn = lib.mkDefault [ "komodo-postgres" ];
          extraOptions = lib.mkDefault [ "--network=komodo-net" ];
        };

        komodo-periphery = {
          image = lib.mkDefault "ghcr.io/moghtech/komodo/periphery:latest";
          environmentFiles = lib.mkDefault [ config.sops.secrets."komodo/periphery_env".path ];
          ports = lib.mkDefault [ "8120:8120" ];
          dependsOn = lib.mkDefault [ "komodo-core" ];
          extraOptions = lib.mkDefault [ "--network=komodo-net" ];
        };
      };
    };

    systemd.services = lib.mkMerge (
      [
        {
          podman-create-komodo-net = {
            description = "Create komodo-net Podman network";
            before = [
              "podman-komodo-postgres.service"
              "podman-komodo-core.service"
              "podman-komodo-periphery.service"
            ];
            wantedBy = lib.mkDefault [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = lib.mkDefault "podman";
              Group = lib.mkDefault "podman";
              Environment = lib.mkDefault [ rtDir homeEnv ];
              ExecStart = lib.mkDefault (
                pkgs.writeShellScript "create-komodo-net" ''
                  ${pkgs.podman}/bin/podman network inspect komodo-net >/dev/null 2>&1 || \\
                    ${pkgs.podman}/bin/podman network create komodo-net
                ''
              );
            };
          };
        }
      ]
      ++ map
        (name: {
          "podman-${name}".serviceConfig = {
            User = lib.mkDefault "podman";
            Group = lib.mkDefault "podman";
            Environment = lib.mkDefault [ rtDir homeEnv ];
          };
        })
        [ "komodo-postgres" "komodo-core" "komodo-periphery" ]
    );
  };
}
