{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# DOZZLE CONTAINER MODULE
# ------------------------------------------------------------------------------
# This module sets up Dozzle, a lightweight, web-based viewer for Docker/Podman
# container logs. It provides real-time logs, basic container management actions,
# and a shell interface directly from your web browser.
################################################################################

let
  cfg = config.ft.containers.dozzle;

  # A static, fake engine-id for Podman compatibility with Dozzle.
  # Dozzle expects to find a Docker engine-id file, which Podman does not natively
  # provide in the same location. This workaround ensures Dozzle functions correctly.
  fakeEngineId = "54c3705a-04b6-4960-9993-5aa3891739b8";

in
{
  options.ft.containers.dozzle = {
    enable = lib.mkEnableOption "Dozzle Log & Shell Viewer";

    # The network port on which Dozzle will be accessible.
    port = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Port for the Dozzle web interface.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure Podman is enabled at the system level for Dozzle to connect.
    virtualisation.podman.enable = true;

    # Create a temporary file to hold the fake engine-id.
    # This file is crucial for Dozzle to recognize Podman as a Docker-compatible backend.
    systemd.tmpfiles.rules = [
      "d /var/lib/dozzle-fix 0755 root root -"
      "f /var/lib/dozzle-fix/engine-id 0644 root root - ${fakeEngineId}"
    ];

    virtualisation.oci-containers.containers.dozzle = {
      image = "amir20/dozzle:latest";
      autoStart = true;
      ports = [ "${toString cfg.port}:8080" ];
      volumes = [
        # Mount the Podman socket as the Docker socket for compatibility.
        "/run/podman/podman.sock:/var/run/docker.sock"
        # Mount the fake Engine ID file as read-only.
        "/var/lib/dozzle-fix/engine-id:/var/lib/docker/engine-id:ro"
      ];
      environment = {
        DOZZLE_ENABLE_ACTIONS = "true";
        DOZZLE_ENABLE_SHELL = "true";
        # Filter to only show running containers by default, reducing clutter.
        DOZZLE_FILTER = "status=running";
      };
    };

    # Open the Dozzle port in the system firewall.
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
