{ lib, config, ... }:

let
  cfg = config.ft.limine;
in
{
  options.ft.limine = {
    enable = lib.mkEnableOption "the Limine bootloader" // {
      description = "Switches the boot loader to Limine and turns off systemd-boot, since having both active at once can leave the boot loader state in a confused mess.";
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
