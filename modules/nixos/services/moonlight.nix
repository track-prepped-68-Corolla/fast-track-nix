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
      description = "Runs a Moonlight-compatible stream host (Sunshine) for remote desktop use and low-latency game streaming, opening the necessary firewall ports by default. Clients connect using Moonlight or Artemis. Anyone streaming from this machine also needs to be a member of the `input` group for virtual-input emulation (gamepad/keyboard/mouse) to work.";
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "sunshine"
        "apollo"
      ];
      default = "sunshine";
      description = "Which stream-host software to use. Only `sunshine` (nixpkgs' built-in `services.sunshine`) is currently implemented; `apollo` is reserved for a future ClassicOldSong/Apollo backend and currently fails, since Apollo isn't packaged in nixpkgs yet.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Opens the firewall ports Moonlight clients need to connect (TCP 47984/47989/47990/48010, UDP 47998-48000/48002/48010). On by default, since a stream host is unreachable without them — turn this off if you'd rather manage the ports yourself or restrict them to a VPN interface.";
    };

    capSysAdmin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Grants `CAP_SYS_ADMIN` on the host binary, which is needed for KMS/Wayland screen capture on many setups. Off by default since it's a privilege escalation — turn it on if screen capture fails under a Wayland session.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Starts the systemd user service automatically whenever you log into a graphical session.";
    };

    installClient = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also installs the Moonlight client (`moonlight-qt`), so this machine can view streams from other hosts, not just serve its own.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Free-form settings passed straight through to `services.sunshine.settings` (e.g. `sunshine_name`, `min_log_level`, `origin_web_ui_allowed`). Merged with this module's own defaults.";
    };

    applications = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "The list of Moonlight applications passed through to `services.sunshine.applications` (the `{ env; apps = [ ... ]; }` structure defining what clients can launch). Merged with this module's own defaults.";
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
