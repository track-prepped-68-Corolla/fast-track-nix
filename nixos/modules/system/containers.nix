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

    # --- 1. System Packages ---
    environment.systemPackages = with pkgs; [
      docker-compose
      distrobox
      podman-compose
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
          ports = [ "8120:8120" ];
          volumes = [
            "/var/lib/komodo/config.toml:/config.toml"
            "komodo_data:/data"
          ];
          environment = {
            TZ = config.time.timeZone;
          };
          # Ensure it restarts if the empty config file causes an initial hiccup
          extraOptions = [ "--label=io.containers.autoupdate=registry" ];
        };

        # Komodo Periphery Container
        periphery = {
          image = "ghcr.io/mbecker20/periphery:latest";
          ports = [ "8121:8120" ];
          volumes = [
            "/var/run/docker.sock:/var/run/docker.sock:ro"
          ];
          environment = {
            TZ = config.time.timeZone;
          };
          extraOptions = [
            "--name=periphery"
            "--privileged" # Gives the container hardware/socket access
            "--user=0" # Ensures it runs as root inside the container
            "--security-opt=label=disable" # Bypasses SELinux/AppArmor restrictions
          ];
        };
      };
    };

    # --- 4. System File Setup (Correctly Indented) ---
    # This ensures the folders and files exist so Podman doesn't create directories where files should be.
    systemd.tmpfiles.rules = [
      "d /var/lib/komodo 0755 ${config.mainuser} users -"
      "f /var/lib/komodo/config.toml 0644 ${config.mainuser} users -"
    ];

    # --- 5. User Permissions ---
    users.users.${config.mainuser} = {
      extraGroups = [ "podman" ];
    };

    # --- 6. Firewall Rules ---
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [
        8120
        8121
      ];
    };
  };
}
