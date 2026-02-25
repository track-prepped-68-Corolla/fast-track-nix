{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# SYSTEM CONTAINER MODULE (The Engine)
# ------------------------------------------------------------------------------
# This file lives in your system configuration (configuration.nix imports).
#
# ROLE:
# It runs as ROOT. It installs the Podman "Engine," configures the Linux kernel,
# and sets up the networking bridges required for containers to talk to the
# outside world.
#
# WHY IS THIS SEPARATE?
# Home Manager (user space) cannot modify system services or kernel settings.
# We must do that here first.
################################################################################

let
  cfg = config.ft.containers;
in
{
  # ----------------------------------------------------------------------------
  # 1. OPTION DEFINITION (The Switch)
  # ----------------------------------------------------------------------------
  # This creates a custom toggle in your system configuration.
  # By setting 'ft.containers.enable = true;' in configuration.nix,
  # you activate everything below.
  options.ft.containers = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable system-level virtualization for Podman.";
    };
  };

  # ----------------------------------------------------------------------------
  # 2. SYSTEM CONFIGURATION (The Logic)
  # ----------------------------------------------------------------------------
  # This block only executes if the switch above is set to 'true'.
  config = lib.mkIf cfg.enable {

    # --- The Core Engine ---
    virtualisation.podman = {
      enable = true;

      # "Docker Compatibility Mode"
      # This creates a symlink at /run/docker.sock pointing to podman.sock.
      # WHY? Many tools (VS Code, old scripts, third-party apps) look for Docker.
      # This trick makes them use Podman transparently without errors.
      dockerCompat = true;

      # DNS Networking
      # Required for containers to resolve domain names (like google.com).
      defaultNetwork.settings.dns_enabled = true;
    };

    # --- OCI Runtime ---
    # Sets Podman as the backend for the OCI (Open Container Initiative) runtime.
    # This is the industry standard layer that actually runs the containers.
    virtualisation.oci-containers.backend = "podman";

    # --- System-Wide Tools ---
    # We install these here so they are available to all users (including root).
    environment.systemPackages = with pkgs; [
      podman-compose # The standard tool for running multi-container apps (docker-compose)
      distrobox # The "Escape Hatch" (allows running Ubuntu/Arch/Fedora inside NixOS)
    ];

    # --- Kernel Tweaks ---
    # By default, Linux prevents non-root users from binding to "low" ports (<1024).
    # We lower this limit to port 80.
    # BENEFIT: You can run a web server container on port 80 without needing 'sudo'.
    boot.kernel.sysctl = {
      "net.ipv4.ip_unprivileged_port_start" = 80;
    };
  };
}
