{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# COSMIC DESKTOP ENVIRONMENT MODULE
# ------------------------------------------------------------------------------
# This module enables and configures the COSMIC Desktop Environment, including
# its display manager (cosmic-greeter) and integration with system76-scheduler
# for optimized performance. It also ensures graphics hardware is enabled.
################################################################################

let
  cfg = config.ft.desktop.cosmic;
in
{
  options.ft.desktop.cosmic = {
    enable = lib.mkEnableOption "COSMIC Desktop Environment";
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.cosmic.enable = lib.mkDefault true;
    services.displayManager.cosmic-greeter.enable = lib.mkDefault true;
    services.system76-scheduler.enable = lib.mkDefault true;
    hardware.graphics.enable = lib.mkDefault true;
  };
}
