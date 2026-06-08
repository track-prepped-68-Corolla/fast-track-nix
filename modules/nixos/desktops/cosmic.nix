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
      description = "Enables the COSMIC desktop environment with cosmic-greeter as the display manager and system76-scheduler for performance-aware process scheduling. Also ensures graphics hardware acceleration is active.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      desktopManager.cosmic.enable = lib.mkDefault true;
      displayManager.cosmic-greeter.enable = lib.mkDefault true;
      system76-scheduler.enable = lib.mkDefault true;
    };
    hardware.graphics.enable = lib.mkDefault true;
  };
}
