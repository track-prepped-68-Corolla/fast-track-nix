{ config, lib, pkgs, ... }:

################################################################################
# JELLYFIN CONTAINER MODULE
# ------------------------------------------------------------------------------
# This module sets up Jellyfin, a free and open-source media system, within
# a Podman container. It's configured for hardware acceleration (specifically
# AMD ROCm/VAAPI, but can be adapted) and robust media management.
################################################################################

let
  cfg = config.ft.containers.jellyfin;

  # Default UID/GID for the Jellyfin container.
  # This is important for file permissions when mounting host volumes.
  puid = 1000;
  pgid = 1000;

  # Base directory for media content. Customize this to point to your media library.
  mediaBaseDir = "/mnt/streaming";

in
{
  options.ft.containers.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin media server";

    # The main port for Jellyfin's web interface.
    port = lib.mkOption {
      type = lib.types.port;
      default = 8096;
      description = "Main port for Jellyfin web interface.";
    };

    # Optional HTTPS port for Jellyfin.
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8920;
      description = "HTTPS port for Jellyfin.";
    };

    # Enable hardware acceleration for media transcoding. Defaults to AMD (VAAPI).
    # Set to 'false' if you don't have a supported GPU or prefer software transcoding.
    enableHardwareAcceleration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable hardware acceleration for transcoding (e.g., VAAPI).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure Podman is enabled at the system level.
    virtualisation.podman.enable = true;

    # Required for hardware acceleration (VAAPI/ROCm).
    # This ensures necessary drivers and firmware are available.
    hardware.graphics = lib.mkIf cfg.enableHardwareAcceleration {
      enable = true;
      enable32Bit = true;
      # Add OpenCL for tone mapping if using ROCm
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];
    };

    # Open necessary firewall ports for Jellyfin to be accessible.
    networking.firewall = {
      allowedTCPPorts = [
        cfg.port
        cfg.httpsPort
      ];
      allowedUDPPorts = [
        1900 # Jellyfin Discovery
        7359 # Jellyfin Discovery
      ];
    };

    # Create the media base directory if it doesn't exist.
    systemd.tmpfiles.rules = [
      "d ${mediaBaseDir} 0775 ${toString puid} ${toString pgid} -"
    ];

    virtualisation.oci-containers.containers.jellyfin = {
      image = "jellyfin/jellyfin:latest";
      autoStart = true;
      ports = [
        "${toString cfg.port}:${toString cfg.port}"
        "${toString cfg.httpsPort}:${toString cfg.httpsPort}"
      ];

      volumes = [
        "${mediaBaseDir}:/media" # Mount your media library
        "jellyfin-config:/config" # Persistent configuration
        "jellyfin-cache:/cache"   # Persistent cache
      ];

      # Environment variables for NVIDIA hardware acceleration (if applicable)
      # Note: For AMD (VAAPI), this section might not be strictly necessary
      # as device mounting often handles it.
      environment = lib.mkIf (cfg.enableHardwareAcceleration && pkgs.stdenv.isLinux) {
        # Set NVIDIA_VISIBLE_DEVICES if using NVIDIA GPU
        NVIDIA_VISIBLE_DEVICES = "all";
      } // {};

      # Mount GPU devices for hardware acceleration.
      extraOptions = lib.mkIf cfg.enableHardwareAcceleration [
        "--device=/dev/dri/renderD128:/dev/dri/renderD128"
        "--device=/dev/dri/card1:/dev/dri/card0" # Adjust card number as needed
        "--device=/dev/kfd:/dev/kfd" # For ROCm (AMD GPU compute)
      ] // [];

      # User and group for the container processes.
      user = "${toString puid}:${toString pgid}";
    };
  };
}
