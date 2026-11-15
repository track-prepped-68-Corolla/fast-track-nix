{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# FRAME SHELL — PC host for the Steam Frame standalone shell
#
# Wraps the upstream frame-shell flake's nixosModules.host (services.frame-shell):
# a WiVRn server plus the shell's host services (monitor capture, input,
# notifications), run as a systemd user service in each graphical session.
# The headset finds the PC over mDNS and pairs with a PIN on first connect.
#
# The headset side (the Monado SteamOS session) is installed on the device
# itself with frame-shell's install.sh — it is not managed by Nix.
#
# Upstream only builds for x86_64-linux.
#
# Exempt from the VM smoke test requirement: hardware-dependent (needs a Steam
# Frame headset and a GPU video encoder to do anything meaningful).
################################################################################

let
  cfg = config.ft.frameShell;
  frameShellPkgs = inputs.frame-shell.packages.x86_64-linux;
in
{
  imports = [ inputs.frame-shell.nixosModules.host ];

  options.ft.frameShell = {
    enable = lib.mkEnableOption "Steam Frame shell PC host" // {
      description = "Runs the PC side of frame-shell, an unofficial standalone shell for the Valve Steam Frame headset: a WiVRn server started as a systemd user service with each graphical session, advertised over mDNS so the headset can find and pair with this machine. The headset side is installed separately on the device. x86_64-linux only. Exempt from VM smoke tests (hardware-dependent).";
    };

    inputUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users whose sessions receive the headset's keyboard and mouse input. They are added to the uinput group.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Starts the frame-shell server automatically with each graphical session. When off, start it manually with `systemctl --user start frame-shell`.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Opens WiVRn's port (9757, TCP and UDP) so the headset can connect over the local network.";
    };

    openvrCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Points the server at frame-shell's patched xrizer build, so OpenVR (SteamVR) games run on the headset through OpenXR.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.services.wivrn.enable;
        message = "ft.frameShell runs its own WiVRn server on port 9757 and conflicts with services.wivrn — disable one of them.";
      }
    ];

    services.frame-shell = {
      enable = lib.mkDefault true;
      inherit (cfg) inputUsers;
      autoStart = lib.mkDefault cfg.autoStart;
      openFirewall = lib.mkDefault cfg.openFirewall;
      # Launch Steam games from the shell when Steam is installed (e.g. via ft.gaming).
      steamPackage = lib.mkIf config.programs.steam.enable (lib.mkDefault config.programs.steam.package);
      settings = lib.optionalAttrs cfg.openvrCompat {
        openvr-compat-path = lib.mkDefault "${frameShellPkgs.xrizer}/lib/xrizer";
      };
    };
  };
}
