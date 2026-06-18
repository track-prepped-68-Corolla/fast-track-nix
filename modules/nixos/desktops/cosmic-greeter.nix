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
      description = "Enables cosmic-greeter as the display manager. Pair with ft.cosmic to boot directly into a COSMIC session.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.cosmic-greeter.enable = lib.mkDefault true;
  };
}
