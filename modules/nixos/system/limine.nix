{ lib, config, ... }:

let
  cfg = config.ft.limine;
in
{
  options.ft.limine = {
    enable = lib.mkEnableOption "the Limine bootloader" // {
      description = "Enables the Limine UEFI bootloader and disables systemd-boot to prevent loader state conflicts.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader = {
      limine.enable = lib.mkDefault true;
      # Required for modern UEFI hardware like the Strix
      efi.canTouchEfiVariables = lib.mkDefault true;
      # Ensure other bootloaders are disabled to prevent state conflicts
      systemd-boot.enable = lib.mkForce false;
    };
  };
}
