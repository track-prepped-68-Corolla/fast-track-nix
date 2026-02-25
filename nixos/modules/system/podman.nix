{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# PODMAN SYSTEM MODULE
# ------------------------------------------------------------------------------
# This module sets up the core Podman container engine at the system level.
# It enables Docker compatibility, configures networking, and includes essential
# tools. It also provides an option for NVIDIA Container Toolkit integration
# for GPU-accelerated containers.
################################################################################

let
  cfg = config.ft.system.podman;
in
{
  options.ft.system.podman = {
    enable = lib.mkEnableOption "Podman container engine and core configurations";

    # Enable NVIDIA Container Toolkit integration for GPU support in containers.
    enableNvidiaIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NVIDIA Container Toolkit integration for GPU support.";
    };

    # The main user for Podman-related permissions.
    user = lib.mkOption {
      type = lib.types.str;
      default = "joe"; # Assuming 'joe' is the default user
      description = "Main user for Podman-related permissions.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Core Podman Engine Configuration
    virtualisation.podman = {
      enable = true; # Enable the Podman service
      dockerCompat = true; # Enable Docker compatibility socket
      defaultNetwork.settings.dns_enabled = true; # Ensure DNS is enabled for containers
    };

    # 2. OCI Runtime Backend
    # Explicitly set Podman as the OCI container backend.
    virtualisation.oci-containers.backend = "podman";

    # 3. NVIDIA Container Toolkit Integration (Conditional)
    # This enables GPU access within containers if the NVIDIA integration is desired.
    hardware.nvidia-container-toolkit.enable = cfg.enableNvidiaIntegration;

    # 4. System-Wide CLI Tools
    # Install common Podman-related tools for all users.
    environment.systemPackages = with pkgs; [
      podman-compose # Docker Compose equivalent for Podman
      distrobox # Tool for creating and managing containerized dev environments
    ];

    # 5. Global Socket Configuration
    # This ensures that tools looking for DOCKER_HOST correctly point to Podman.
    environment.extraInit = ''
      if [ -z "$DOCKER_HOST" -a -n "$XDG_RUNTIME_DIR" ]; then
        export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
      fi
    '';

    # 6. User Permissions
    # Add the specified user to necessary groups for Podman and NVIDIA access.
    users.users.${cfg.user} = {
      extraGroups = [
        "podman"
      ] # Add to podman group for rootless container management
      ++ lib.optionals cfg.enableNvidiaIntegration [
        "video" # For general GPU access
        "render" # For rendering capabilities
      ];
      linger = true; # Allow user services to run after user logs out
    };

    # 7. Kernel Tweaks for Rootless Podman
    # Allows unprivileged users to bind to low ports (e.g., port 80 for web servers).
    boot.kernel.sysctl = {
      "net.ipv4.ip_unprivileged_port_start" = 80;
    };
  };
}
