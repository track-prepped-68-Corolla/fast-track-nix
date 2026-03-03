{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ft.containers;
in
{
  options.ft.containers = {
    enable = lib.mkEnableOption "the FT container stack (Podman, Distrobox, Komodo)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      docker-compose
      distrobox
      podman-compose
    ];

    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      oci-containers.backend = "podman";

      oci-containers.containers = {
        # --- MongoDB ---
        komodo-db = {
          image = "mongo:latest";
          volumes = [ "/var/lib/komodo/mongodb:/data/db" ];
          extraOptions = [ "--network=host" ];
        };

        # --- Komodo Core ---
        komodo = {
          image = "ghcr.io/mbecker20/komodo:latest";
          ports = [ "8120:9120" ];
          volumes = [ "/var/lib/komodo/config.toml:/config/config.toml" ];
          # This tells NixOS to start the DB service first
          dependsOn = [ "komodo-db" ];
          environment = {
            TZ = config.time.timeZone;
            KOMODO_CONFIG_PATH = "/config/config.toml";
          };
          extraOptions = [ "--network=host" ];
        };

        periphery = {
          image = "ghcr.io/mbecker20/periphery:latest";
          ports = [ "8121:8120" ];
          volumes = [ "/run/podman/podman.sock:/var/run/docker.sock:ro" ];
          environment = {
            TZ = config.time.timeZone;
            PERIPHERY_PASSKEY = "default-passkey-changeme";
          };
          extraOptions = [
            "--name=periphery"
            "--privileged"
            "--user=0"
            "--security-opt=label=disable"
          ];
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/komodo 0775 root root -"
      "d /var/lib/komodo/data 0775 root root -"
      "f /var/lib/komodo/config.toml 0664 root root -"
    ];

    networking.firewall.allowedTCPPorts = [
      8120
      8121
      9120
    ];
    users.users.${config.mainuser}.extraGroups = [
      "podman"
      "docker"
    ];
  };
}
