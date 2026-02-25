{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# ARR STACK CONTAINER MODULE
# ------------------------------------------------------------------------------
# This module sets up the "Arr" stack of applications (Radarr, Sonarr, Prowlarr,
# Bazarr, Lidarr, Qbittorrent) along with Gluetun (VPN) for secure media
# management and Jellyfin for media streaming.
#
# SECURITY NOTE:
# The `WIREGUARD_PRIVATE_KEY` is hardcoded here for simplicity. For a production
# environment, it is highly recommended to use `sops-nix` for managing secrets.
# See: https://github.com/Mic92/sops-nix
################################################################################

let
  cfg = config.ft.containers.arr;

  # Default UID/GID for containers. Assumes a user with UID/GID 1000 exists.
  # This is a common practice to avoid permission issues with host volumes.
  puid = 1000;
  pgid = 1000;

  # Base directory for all Arr stack data. Customize as needed.
  mediaBaseDir = "/media/arr";

in
{
  options.ft.containers.arr = {
    enable = lib.mkEnableOption "Arr Stack (Radarr, Sonarr, etc.) with VPN and Jellyfin";

    # WireGuard VPN private key for Gluetun. IMPORTANT: Use sops-nix for production!
    wireguardPrivateKey = lib.mkOption {
      type = lib.types.str;
      default = ""; # Placeholder - user must provide
      description = "WireGuard private key for Gluetun VPN.";
      # This option should ideally be managed via sops-nix
      # example: config.sops.secrets.wireguardPrivateKey.path
    };

    # VPN service provider for Gluetun (e.g., "protonvpn", "nordvpn").
    vpnServiceProvider = lib.mkOption {
      type = lib.types.str;
      default = "protonvpn";
      description = "VPN service provider for Gluetun.";
    };

    # Comma-separated list of VPN server countries (e.g., "Iceland,Switzerland").
    vpnServerCountries = lib.mkOption {
      type = lib.types.str;
      default = "Iceland,Switzerland,Sweden";
      description = "Comma-separated list of VPN server countries.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure Podman is enabled at the system level
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    # Open Firewall Ports for all services.
    # Note: Gluetun handles internal routing for Arr apps, but Jellyfin needs direct ports.
    networking.firewall = {
      allowedTCPPorts = [
        8096 # Jellyfin Web UI
        8920 # Jellyfin HTTPS
        9696 # Prowlarr
        7878 # Radarr
        8989 # Sonarr
        6767 # Bazarr
        8686 # Lidarr
        8080 # Qbittorrent WebUI
        6881 # Qbittorrent TCP
      ];
      allowedUDPPorts = [
        1900 # Jellyfin Discovery
        7359 # Jellyfin Discovery
        6881 # Qbittorrent UDP
      ];
    };

    # Create necessary media directories if they don't exist
    systemd.tmpfiles.rules = [
      "d ${mediaBaseDir} 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/radarr/config 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/radarr/movies 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/sonarr/config 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/sonarr/tvseries 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/prowlarr/config 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/bazarr/config 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/lidarr/config 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/lidarr/music 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/qbittorrent/config 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/qbittorrent/downloads 0775 ${toString puid} ${toString pgid} -"
      "d ${mediaBaseDir}/jellyfin/config 0775 ${toString puid} ${toString pgid} -"
    ];

    virtualisation.oci-containers.containers = {
      # --- GLUETUN (VPN) Container ---
      gluetun = {
        image = "qmcgaw/gluetun";
        autoStart = true;
        environment = {
          VPN_SERVICE_PROVIDER = cfg.vpnServiceProvider;
          VPN_TYPE = "wireguard";
          SERVER_COUNTRIES = cfg.vpnServerCountries;
          WIREGUARD_PRIVATE_KEY = cfg.wireguardPrivateKey;
          PORT_FORWARD_ONLY = "on";
          VPN_PORT_FORWARDING = "on";
        };
        ports = [
          "9696:9696" # Prowlarr
          "7878:7878" # Radarr
          "8989:8989" # Sonarr
          "6767:6767" # Bazarr
          "8686:8686" # Lidarr
          "8080:8080" # Qbittorrent WebUI
          "6881:6881" # Qbittorrent TCP
          "6881:6881/udp" # Qbittorrent UDP
        ];
        extraOptions = [
          "--cap-add=NET_ADMIN"
          "--device=/dev/net/tun:/dev/net/tun"
        ];
      };

      # --- RADARR Container ---
      radarr = {
        image = "lscr.io/linuxserver/radarr:latest";
        autoStart = true;
        environment = {
          PUID = toString puid;
          PGID = toString pgid;
          TZ = "Etc/UTC";
        };
        volumes = [
          "${mediaBaseDir}/radarr/config:/config"
          "${mediaBaseDir}/radarr/movies:/movies"
          "${mediaBaseDir}/qbittorrent/downloads:/downloads"
        ];
        extraOptions = [ "--network=container:gluetun" ];
        dependsOn = [ "gluetun" ];
      };

      # --- SONARR Container ---
      sonarr = {
        image = "lscr.io/linuxserver/sonarr:latest";
        autoStart = true;
        environment = {
          PUID = toString puid;
          PGID = toString pgid;
          TZ = "Etc/UTC";
        };
        volumes = [
          "${mediaBaseDir}/sonarr/config:/config"
          "${mediaBaseDir}/sonarr/tvseries:/tv"
          "${mediaBaseDir}/qbittorrent/downloads:/downloads"
        ];
        extraOptions = [ "--network=container:gluetun" ];
        dependsOn = [ "gluetun" ];
      };

      # --- PROWLARR Container ---
      prowlarr = {
        image = "lscr.io/linuxserver/prowlarr:latest";
        autoStart = true;
        environment = {
          PUID = toString puid;
          PGID = toString pgid;
          TZ = "Etc/UTC";
        };
        volumes = [ "${mediaBaseDir}/prowlarr/config:/config" ];
        extraOptions = [ "--network=container:gluetun" ];
        dependsOn = [ "gluetun" ];
      };

      # --- BAZARR Container ---
      bazarr = {
        image = "lscr.io/linuxserver/bazarr:latest";
        autoStart = true;
        environment = {
          PUID = toString puid;
          PGID = toString pgid;
          TZ = "Etc/UTC";
        };
        volumes = [
          "${mediaBaseDir}/bazarr/config:/config"
          "${mediaBaseDir}/radarr/movies:/movies"
          "${mediaBaseDir}/sonarr/tvseries:/tv"
        ];
        extraOptions = [ "--network=container:gluetun" ];
        dependsOn = [ "gluetun" ];
      };

      # --- LIDARR Container ---
      lidarr = {
        image = "lscr.io/linuxserver/lidarr:latest";
        autoStart = true;
        environment = {
          PUID = toString puid;
          PGID = toString pgid;
          TZ = "Etc/UTC";
        };
        volumes = [
          "${mediaBaseDir}/lidarr/config:/config"
          "${mediaBaseDir}/lidarr/music:/music"
          "${mediaBaseDir}/qbittorrent/downloads:/downloads"
        ];
        extraOptions = [ "--network=container:gluetun" ];
        dependsOn = [ "gluetun" ];
      };

      # --- QBITTORRENT Container ---
      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:latest";
        autoStart = true;
        environment = {
          PUID = toString puid;
          PGID = toString pgid;
          TZ = "Etc/UTC";
          WEBUI_PORT = "8080";
          TORRENTING_PORT = "6881";
        };
        volumes = [
          "${mediaBaseDir}/qbittorrent/config:/config"
          "${mediaBaseDir}/qbittorrent/downloads:/downloads"
        ];
        extraOptions = [ "--network=container:gluetun" ];
        dependsOn = [ "gluetun" ];
      };

      # --- JELLYFIN (Standalone) Container ---
      jellyfin = {
        image = "lscr.io/linuxserver/jellyfin:latest";
        autoStart = true;
        environment = {
          PUID = toString puid;
          PGID = toString pgid;
          TZ = "Etc/UTC";
        };
        ports = [
          "8096:8096"
          "8920:8920"
          "7359:7359/udp"
          "1900:1900/udp"
        ];
        volumes = [
          "${mediaBaseDir}/jellyfin/config:/config"
          "${mediaBaseDir}/sonarr/tvseries:/data/tvshows"
          "${mediaBaseDir}/radarr/movies:/data/movies"
        ];
      };
    };
  };
}
