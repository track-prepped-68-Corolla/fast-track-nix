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
          volumes = [
            "/var/lib/komodo/config.toml:/config/config.toml"
            "/var/lib/komodo/stacks:/etc/komodo/stacks"
            "/var/lib/komodo/repos:/repo-cache"
            "/var/lib/komodo/syncs:/syncs"
          ];
          dependsOn = [ "komodo-db" ];
          environment = {
            TZ = config.time.timeZone;
            KOMODO_CONFIG_PATH = "/config/config.toml";
          };
          extraOptions = [ "--network=host" ];
        };

        # --- Periphery ---
        periphery = {
          image = "ghcr.io/mbecker20/periphery:latest";
          environment = {
            # Note the plural and the prefix - this is what the backend looks for
            PASSKEYS = "default-passkey-changeme";
            PORT = "8121";
            STACK_DIR = "/etc/komodo/stacks";
            REPO_DIR = "/etc/komodo/repos";
          };
          volumes = [
            "/run/podman/podman.sock:/var/run/docker.sock"
            "/etc/komodo:/etc/komodo"
          ];
          extraOptions = [
            "--network=host"
            "--privileged"
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
      27017
    ];
    users.users.${config.mainuser}.extraGroups = [
      "podman"
      "docker"
    ];
  };
}
