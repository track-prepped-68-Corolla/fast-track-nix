{ config, lib, pkgs, ... }:

################################################################################
# TAILSCALE VPN CLIENT MODULE
################################################################################

let
  cfg = config.ft.services.tailscale;
in
{
  options.ft.services.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN client" // {
      description = "Connects the machine to a Tailscale mesh network, trusts the tailscale0 interface in the firewall, and installs the Trayscale GUI tray app. Set `ft.services.tailscale.useRoutingFeatures = \"server\"` to run as an exit node.";
    };

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
