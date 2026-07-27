{ config, lib, ... }:

################################################################################
# COSMIC DESKTOP ENVIRONMENT MODULE
################################################################################

let
  cfg = config.ft.cosmic;
in
{
  options.ft.cosmic = {
    enable = lib.mkEnableOption "COSMIC Desktop Environment" // {
      description = "Turns on the COSMIC desktop environment along with system76-scheduler, which prioritizes process scheduling for better responsiveness, and makes sure graphics hardware acceleration is on. Pair it with `ft.cosmicGreeter` to use cosmic-greeter as the login screen, or set up a different display manager to launch the COSMIC session instead.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      desktopManager.cosmic.enable = lib.mkDefault true;
      system76-scheduler.enable = lib.mkDefault true;
    };
    hardware.graphics.enable = lib.mkDefault true;
  };
}
