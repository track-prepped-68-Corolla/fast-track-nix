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
  options.ft.yubikey = {
    enable = lib.mkEnableOption "YubiKey support and PAM integration" // {
      description = "Installs YubiKey management tools (`yubikey-manager`, `yubico-piv-tool`, `pam_u2f`), turns on the `pcscd` smart-card service, and activates `ft.users.u2f` so YubiKeys can be used for login. Set each user's FIDO2 credentials with `ft.users.u2f.mappings` in your machine config.";
    };
  };

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

    # YubiKey is a USB HID device; guarantee the driver loads regardless of
    # what facter-modules derives from the hardware report.
    boot.kernelModules = [ "usbhid" ];

    # Activate the shared U2F PAM stack owned by user.nix.
    ft.users.u2f.enable = lib.mkDefault true;

    # user.nix owns security.pam.u2f — only add the display manager here.
    # cosmic-greeter is excluded: the greeter doesn't relay pam_u2f prompts
    # reliably and a hang there locks the user out completely. cosmic-lock
    # (the screen locker) is sufficient for DE-level key protection.
    security.pam.services = {
      sddm.u2fAuth = true;
      cosmic-lock.u2fAuth = true;
    };
  };
}
