{ lib, config, ... }:

{
  options.ft.boot.limine = {
    enable = lib.mkEnableOption "the Limine bootloader" // {
      description = "Switches the bootloader to Limine, enables EFI variable writes (`canTouchEfiVariables`), and force-disables systemd-boot to prevent conflicts. Use on any UEFI system where you prefer Limine over the default systemd-boot.";
    };
  };

  config = lib.mkIf config.ft.boot.limine.enable {
    boot.loader = {
      limine.enable = true;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = lib.mkForce false;
    };
  };
}
