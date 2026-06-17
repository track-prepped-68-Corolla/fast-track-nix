{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# TAILSCALE VPN CLIENT MODULE
################################################################################

let
  cfg = config.ft.tailscale;
in
{
  options.ft.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN client" // {
      description = "Connects the machine to a Tailscale mesh network, trusts the tailscale0 interface in the firewall, and installs the Trayscale GUI tray app. Set `ft.tailscale.useRoutingFeatures = \"server\"` to run as an exit node.";
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

    autoJoin = lib.mkOption {
      type = lib.types.bool;
      default = config.ft.sops.enable;
      description = ''
        Declares the `tailscale/authkey` sops secret and points
        `services.tailscale.authKeyFile` at it, so tailscaled authenticates and
        joins the tailnet automatically on first boot instead of requiring a
        manual `sudo tailscale up`. Defaults to `ft.sops.enable`, so any machine
        with sops already enabled auto-joins with no extra toggle. Requires a
        `tailscale/authkey` value populated in the encrypted secrets file. The
        key must be a reusable auth key generated in the Tailscale admin
        console; if it expires, rotate it and re-encrypt the secrets file or
        auto-join silently stops working for any newly built machine.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.autoJoin || config.ft.sops.enable;
        message = "ft.tailscale.autoJoin requires ft.sops.enable = true";
      }
    ];

    services.tailscale = {
      enable = true;
      inherit (cfg) useRoutingFeatures;
      authKeyFile = lib.mkIf cfg.autoJoin (
        lib.mkDefault config.sops.secrets."tailscale/authkey".path
      );
    };

    sops.secrets."tailscale/authkey" = lib.mkIf cfg.autoJoin { };

    environment.systemPackages = lib.mkIf cfg.enableTrayApp [ pkgs.trayscale ];

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      checkReversePath = "loose";
    };
  };
}
