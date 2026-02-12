{ config, lib, pkgs, ... }:

################################################################################
# SEARXNG CONTAINER MODULE
# ------------------------------------------------------------------------------
# This module sets up SearXNG, a free internet metasearch engine, within a
# Podman container. It bundles SearXNG with a Redis backend for caching and
# integrates with sops-nix for secure management of sensitive environment variables.
#
# SECURITY NOTE:
# This module *requires* sops-nix for `searxng_env` secret management. Ensure
# you have sops-nix configured in your flake and secrets defined.
################################################################################

let
  cfg = config.ft.containers.searxng;
  networkName = "searxng-net"; # Custom Podman network for SearXNG and Redis.
in
{
  options.ft.containers.searxng = {
    enable = lib.mkEnableOption "SearXNG container with Redis and Sops integration";

    # The host port to bind the SearXNG web interface to.
    port = lib.mkOption {
      type = lib.types.port;
      default = 6080;
      description = "The host port to bind SearXNG to.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure Podman is enabled at the system level.
    virtualisation.podman.enable = true;

    # --- Sops-Nix Integration ---
    # Define a sops secret for SearXNG environment variables. This is crucial
    # for managing sensitive data (like API keys) securely.
    # The container will be restarted if the secret changes.
    sops.secrets."searxng_env" = {
      restartUnits = [ "podman-searxng.service" ];
    };

    # --- Network Initialization ---
    # A systemd service to create a dedicated Podman network for SearXNG and Redis.
    # This ensures proper isolation and communication between the two containers.
    systemd.services.init-searxng-network = {
      description = "Create network for SearXNG";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.podman}/bin/podman network create ${networkName} --ignore";
      };
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-searxng.service"
        "podman-searxng-redis.service"
      ];
    };

    # --- OCI Containers ---
    virtualisation.oci-containers.containers = {
      # Redis container: Backend for caching SearXNG queries.
      searxng-redis = {
        image = "docker.io/library/redis:alpine";
        cmd = [
          "redis-server"
          "--save"
          "" # No saving to disk for simplicity/ephemerality
          "--appendonly"
          "no"
        ];
        autoStart = true;
        extraOptions = [ "--network=${networkName}" ]; # Connect to the custom network
      };

      # SearXNG container: The metasearch engine itself.
      searxng = {
        image = "docker.io/searxng/searxng:latest";
        autoStart = true;
        ports = [ "${toString cfg.port}:6080" ]; # Expose SearXNG to the host network

        # Inject environment variables from the sops secret file.
        environmentFiles = [ config.sops.secrets."searxng_env".path ];

        environment = {
          SEARXNG_BASE_URL = "http://localhost:${toString cfg.port}/";
          SEARXNG_REDIS_URL = "redis://searxng-redis:6379/0"; # Connect to Redis container
        };

        extraOptions = [
          "--network=${networkName}" # Connect to the custom network
          "--dns=1.1.1.1"           # Use a reliable DNS resolver within the container
        ];
      };
    };

    # Open the SearXNG port in the system firewall.
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
