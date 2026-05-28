{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.yubikey;
in
{
  meta.description = "Installs YubiKey management tools (yubikey-manager, yubico-piv-tool, pam_u2f), enables pcscd, and activates ft.user.u2f. Set per-user FIDO2 credentials via ft.user.u2f.mappings in your machine config.";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      yubikey-manager
      yubico-piv-tool
      pam_u2f
    ];

    services = {
      pcscd.enable = true;
      udev.packages = [ pkgs.yubikey-personalization ];
    };

    boot.kernelModules = [ "usbhid" ];

    ft.user.u2f.enable = lib.mkDefault true;

    security.pam.services = {
      sddm.u2fAuth = true;
      cosmic-lock.u2fAuth = true;
    };
  };
}
