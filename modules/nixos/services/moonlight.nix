{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# MOONLIGHT STREAM HOST — Apollo/Sunshine remote desktop & game streaming
# ------------------------------------------------------------------------------
# Wraps nixpkgs' `services.sunshine` to expose a Moonlight-compatible stream
# host (remote desktop + low-latency game streaming) behind the `ft.*` option
# convention, mirroring how `ft.tailscale` wraps `services.tailscale`.
#
# `backend` is an enum so an Apollo (ClassicOldSong/Apollo) implementation can
# be slotted in later without renaming the feature. Only `sunshine` is wired
# today; selecting `apollo` fails an assertion because Apollo is not yet
# packaged in nixpkgs and its only known Nix flake is unmaintained/archived.
#
# The upstream `services.sunshine` module owns the low-level plumbing — the
# `uinput` kernel module + udev rule, the `CAP_SYS_ADMIN` binary wrapper, and
# the systemd *user* service — so this module does not duplicate any of it.
# Note: input emulation (virtual gamepad/keyboard/mouse) requires the streaming
# user to be a member of the `input`/`uinput` group; add that in the user's own
# config, as group membership is user-specific and cannot live in the framework.
#
# Not exempt from VM smoke tests: GPU encode and KMS capture are
# hardware-dependent, but the systemd user unit, the `sunshine` binary on PATH,
# and the opened firewall ports are all assertable in a headless VM. The test
# lives in ft-testing/tests/vm/, not here.
################################################################################

let
  cfg = config.ft.moonlight;
in
{
  options.ft.moonlight = {
    enable = lib.mkEnableOption "Moonlight stream host" // {
      description = "Runs a Moonlight-compatible stream host (Sunshine) for remote desktop and low-latency game streaming, opening the Moonlight port set in the firewall by default. Clients connect with Moonlight/Artemis. Streaming users must additionally be members of the `input` group for virtual-input emulation.";
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "sunshine"
        "apollo"
      ];
      default = "sunshine";
      description = "Stream-host implementation. Only `sunshine` (nixpkgs' in-tree `services.sunshine`) is implemented; `apollo` is reserved for a future ClassicOldSong/Apollo backend and currently fails an assertion because Apollo is not packaged in nixpkgs.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the Moonlight port set in the firewall (TCP 47984/47989/47990/48010, UDP 47998-48000/48002/48010). Enabled by default — a stream host is unreachable without it — but can be disabled to manage the ports manually or restrict them to a VPN interface.";
    };

    capSysAdmin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Grant `CAP_SYS_ADMIN` on the host binary, required for KMS/Wayland screen capture on many setups. Disabled by default because it is a privilege escalation; enable it if screen capture fails under a Wayland session.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the systemd *user* service automatically on login to a graphical session.";
    };

    installClient = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also install the Moonlight client (`moonlight-qt`) so this machine can view streams from other hosts, not just serve them.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Free-form settings passed through to `services.sunshine.settings` (e.g. `sunshine_name`, `min_log_level`, `origin_web_ui_allowed`). Merged with the module defaults.";
    };

    applications = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Moonlight application list passed through to `services.sunshine.applications` (the `{ env; apps = [ ... ]; }` structure defining the entries clients can launch). Merged with the module defaults.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.backend == "sunshine";
        message = "ft.moonlight.backend = \"apollo\" is not yet implemented — Apollo is not packaged in nixpkgs. Use backend = \"sunshine\".";
      }
    ];

    services.sunshine = lib.mkIf (cfg.backend == "sunshine") {
      enable = true;
      # Scalars wrapped so a consumer can still override services.sunshine.*
      # directly without mkForce; settings/applications left unwrapped to merge.
      openFirewall = lib.mkDefault cfg.openFirewall;
      capSysAdmin = lib.mkDefault cfg.capSysAdmin;
      autoStart = lib.mkDefault cfg.autoStart;
      inherit (cfg) settings applications;
    };

    # Optional client so the machine can also act as a Moonlight viewer.
    environment.systemPackages = lib.optional cfg.installClient pkgs.moonlight-qt;
  };
}
