{ config, lib, ... }:

################################################################################
# COSMIC GREETER DISPLAY MANAGER MODULE
################################################################################

let
  cfg = config.ft.cosmicGreeter;
in
{
  options.ft.cosmicGreeter = {
    enable = lib.mkEnableOption "cosmic-greeter display manager" // {
      description = "Turns on cosmic-greeter as the login screen. Pair it with `ft.cosmic` to boot straight into a COSMIC session.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.cosmic-greeter.enable = lib.mkDefault true;
  };
}
