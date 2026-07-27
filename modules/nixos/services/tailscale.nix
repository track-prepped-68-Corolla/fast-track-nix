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
      description = "Joins the machine to a Tailscale mesh network, trusts the tailscale0 interface in the firewall, and installs the Trayscale tray app. Set `ft.tailscale.useRoutingFeatures = \"server\"` to run this machine as an exit node.";
    };

    enableTrayApp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Installs the Trayscale graphical tray application.";
    };

    useRoutingFeatures = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
      ];
      default = "client";
      description = "Whether this machine acts as a regular Tailscale client or as a server/exit node.";
    };

    autoJoin = lib.mkOption {
      type = lib.types.bool;
      default = config.ft.sops.enable;
      description = ''
        Declares the `tailscale/authkey` sops secret and points
        `services.tailscale.authKeyFile` at it, so tailscaled logs in and joins
        the tailnet automatically on first boot instead of needing a manual
        `sudo tailscale up`. Defaults to whatever `ft.sops.enable` is set to, so
        any machine that already has sops enabled joins automatically with no
        extra toggle. Requires a `tailscale/authkey` value in the encrypted
        secrets file — it must be a reusable auth key generated in the
        Tailscale admin console. If that key expires, rotate it and re-encrypt
        the secrets file, or auto-join will silently stop working for any
        newly built machine.
      '';
    };

    useSSH = lib.mkEnableOption "Tailscale SSH" // {
      description = "Turns on Tailscale's built-in SSH server (`tailscale up --ssh`), so tailnet peers can connect over SSH using their Tailscale identity instead of a separate SSH keypair — including through Tailscale's browser-based SSH Console, with no client app or authorized_keys entry required. Who can actually connect is controlled entirely by your tailnet's ACL policy in the Tailscale admin console, not by this option.";
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
      authKeyFile = lib.mkIf cfg.autoJoin (lib.mkDefault config.sops.secrets."tailscale/authkey".path);
      extraUpFlags = lib.mkIf cfg.useSSH (lib.mkDefault [ "--ssh" ]);
    };

    sops.secrets."tailscale/authkey" = lib.mkIf cfg.autoJoin { };

    environment.systemPackages = lib.mkIf cfg.enableTrayApp [ pkgs.trayscale ];

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      checkReversePath = "loose";
    };
  };
}
