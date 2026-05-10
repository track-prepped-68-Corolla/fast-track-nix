{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# TAILSCALE VPN CLIENT MODULE
# ------------------------------------------------------------------------------
# This module enables and configures the Tailscale VPN client, a zero-config
# VPN for building secure networks. It integrates with the `trayscale` GUI
# for desktop environments and sets up necessary firewall rules.
################################################################################

let
  cfg = config.ft.services.tailscale;
in
{
  options.ft.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN client";

    enableTrayApp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Trayscale GUI tray application.";
    };

    useRoutingFeatures = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
      ];
      default = "client";
      description = "Tailscale routing features (client or server/exit node).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.useRoutingFeatures;
    };

    environment.systemPackages = lib.mkIf cfg.enableTrayApp [
      pkgs.trayscale
    ];

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      checkReversePath = "loose";
    };
  };
}
