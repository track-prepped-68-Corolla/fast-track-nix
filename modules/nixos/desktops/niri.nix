{ config, lib, ... }:

################################################################################
# NIRI SCROLLABLE-TILING WAYLAND COMPOSITOR SESSION
################################################################################

let
  cfg = config.ft.niri;
in
{
  options.ft.niri = {
    enable = lib.mkEnableOption "niri Wayland session" // {
      description = "Turns on niri, a scrollable-tiling Wayland compositor, and registers it as a selectable login session. niri needs a display manager to present that session — pair it with `ft.cosmicGreeter` or `ft.plasma` (or any other display manager), whichever is already configured as the machine's primary one. Pair it with `ft.noctalia` for a bar/shell to run inside the session.";
    };

    defaultSession = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Makes niri the default session the display manager starts (including for autologin), instead of just offering it as one option alongside whatever other sessions are configured.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri.enable = lib.mkDefault true;

    # Plain value, not mkDefault: guarded by cfg.defaultSession so it only
    # fires when the consumer explicitly opts in, behaving as a
    # consumer-directed override rather than a hardcoded opinion (same
    # pattern as ft.plasmaBigscreen's defaultSession).
    services.displayManager.defaultSession = lib.mkIf cfg.defaultSession "niri";
  };
}
