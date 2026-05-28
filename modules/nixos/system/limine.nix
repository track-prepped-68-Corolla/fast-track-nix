{ lib, config, ... }:

{
  meta.description = "Configures the Limine bootloader for modern UEFI hardware: enables efi.canTouchEfiVariables and force-disables systemd-boot to prevent state conflicts.";

  config = lib.mkIf config.ft.limine.enable {
    boot.loader = {
      limine.enable = true;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = lib.mkForce false;
    };
  };
}
