{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# DISTROBOX CONTAINER MODULE
# ------------------------------------------------------------------------------
# This module sets up Distrobox, a powerful tool for creating and managing
# containerized development environments. It allows you to run different Linux
# distributions side-by-side with your NixOS host, providing flexibility for
# development and testing.
################################################################################

let
  cfg = config.ft.containers.distrobox;
in
{
  options.ft.containers.distrobox = {
    enable = lib.mkEnableOption "Distrobox container management";

    # Enable or disable BoxBuddy, a graphical user interface for Distrobox.
    # BoxBuddy provides an easier way to manage Distrobox containers.
    enableBoxBuddy = lib.mkEnableOption "BoxBuddy (GUI for Distrobox)";
  };

  config = lib.mkIf cfg.enable {
    # 1. Install Distrobox & optional GUI
    # Distrobox is the core tool, and BoxBuddy provides a convenient GUI.
    environment.systemPackages = [
      pkgs.distrobox
    ]
    ++ (lib.optionals cfg.enableBoxBuddy [ pkgs.boxbuddy ]);

    # 2. Assert that a backend is available
    # Distrobox relies on either Podman or Docker to function. This assertion
    # ensures that one of these container runtimes is enabled in the system
    # configuration, preventing Distrobox from being enabled without a backend.
    assertions = [
      {
        assertion = config.virtualisation.podman.enable || config.virtualisation.docker.enable;
        message = "Distrobox requires either Podman or Docker to be enabled in your configuration.";
      }
    ];
  };
}
