{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# SYSTEM CONTAINER MODULE (The Engine)
# ------------------------------------------------------------------------------
# ROLE: Installs Podman, configures Kernel settings, and prepares /opt paths.
################################################################################

let
  cfg = config.ft.containers;
in
{
  # ----------------------------------------------------------------------------
  # 1. OPTION DEFINITION
  # ----------------------------------------------------------------------------
  options.ft.containers = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable system-level virtualization for Podman.";
    };
  };

  # ----------------------------------------------------------------------------
  # 2. SYSTEM CONFIGURATION
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {

    # --- The Core Engine ---
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    # Sets Podman as the backend for the OCI (Open Container Initiative) runtime.
    virtualisation.oci-containers.backend = "podman";

    # --- Directory Permissions & Setup ---
    # This creates the /opt folders required by your AI and System containers.
    # 'd' creates the directory if it doesn't exist.
    # '0775' allows root/group write access and world read access.
    systemd.tmpfiles.rules = [
      "d /opt/ai-models 0775 root root -"
      "d /opt/llama-cpp 0775 root root -"
      "d /opt/comfyui 0775 root root -"
      "d /opt/open-webui 0775 root root -"
    ];

    # --- System-Wide Tools ---
    environment.systemPackages = with pkgs; [
      podman-compose
      distrobox
    ];

    # --- Kernel Tweaks ---
    # Allows binding to port 80 without sudo.
    boot.kernel.sysctl = {
      "net.ipv4.ip_unprivileged_port_start" = 80;
    };
  };
}
