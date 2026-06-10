{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ft.asus;
in
{
  options.ft.asus = {
    enable = lib.mkEnableOption "ASUS ROG/TUF laptop hardware support" // {
      description = "Enables asusd and asusctl for ASUS ROG/TUF laptops, providing fan curve management, keyboard RGB/anime matrix control, and battery charge limit support. Exempt from VM smoke tests: requires real ASUS hardware.";
    };

    enableUserService = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the asusd user service for per-user RGB lighting and anime matrix control.";
    };
  };
    environment.systemPackages = [ pkgs.asusctl ];
  };
}
