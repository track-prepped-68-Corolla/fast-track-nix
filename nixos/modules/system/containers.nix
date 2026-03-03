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
  # --- Define the Option ---
  options.ft.containers = {
    enable = lib.mkEnableOption "the FT container stack (Podman, Distrobox, Komodo)";
  };

  # --- Apply the Configuration ---
  config = lib.mkIf cfg.enable {

    # --- 1. System Packages (All of them!) ---
    environment.systemPackages = with pkgs; [
      docker-compose
      distrobox
      podman-compose
      curl
    ];

    # --- 2. Container Engine (Podman) Setup ---
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      # --- 3. OCI Containers (Systemd Managed) ---
      oci-containers.backend = "podman";

      oci-containers.containers = {
        # Komodo Core Container
        komodo = {
          image = "ghcr.io/mbecker20/komodo:latest";
          # Host 8120 -> Internal 9120 (Komodo's default internal port)
          ports = [ "8120:9120" ];
          volumes = [
            "/var/lib/komodo/config.toml:/config/config.toml"
            "/var/lib/komodo/data:/data"
          ];
          environment = {
            TZ = config.time.timeZone;
            KOMODO_CONFIG_PATH = "/config/config.toml";
            KOMODO_DATABASE_URI = "sqlite:///data/komodo.db";
          };
          # Ensure it restarts & relabels the data volume for permissions
          extraOptions = [
            "--label=io.containers.autoupdate=registry"
            "--mount=type=bind,source=/var/lib/komodo/data,target=/data,relabel=shared"
          ];
        };

        # Komodo Periphery Container
        periphery = {
          image = "ghcr.io/mbecker20/periphery:latest";
          ports = [ "8121:8120" ];
          volumes = [
            "/run/podman/podman.sock:/var/run/docker.sock:ro"
          ];
          environment = {
            TZ = config.time.timeZone;
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

    # --- 4. System File Setup ---
    # We set these to root:root 0775 so Podman (system level) has zero friction
    systemd.tmpfiles.rules = [
      "d /var/lib/komodo 0775 root root -"
      "d /var/lib/komodo/data 0775 root root -"
      "f /var/lib/komodo/config.toml 0664 root root -"
    ];

    # --- 5. User Permissions ---
    users.users.${config.mainuser} = {
      extraGroups = [
        "podman"
        "docker"
      ];
    };

    # --- 6. Firewall Rules ---
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        8120
        8121
        9120
      ];
    };
  };
}
