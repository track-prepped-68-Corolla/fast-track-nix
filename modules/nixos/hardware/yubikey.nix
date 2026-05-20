{ config, lib, pkgs, ... }:

let
  cfg = config.ft.hardware.yubikey;
in
{
  options.ft.hardware.yubikey = {
    enable = lib.mkEnableOption "YubiKey support and PAM integration" // {
      description = "Installs YubiKey management tools (yubikey-manager, yubico-piv-tool, pam_u2f) and enables PAM U2F authentication for login, sudo, SDDM, cosmic-greeter, and cosmic-lock. Set `ft.hardware.yubikey.u2fMapping` to your key's registration string.";
    };

    u2fMapping = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The U2F registration string for the YubiKey. Set in your host file.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ yubikey-manager yubico-piv-tool pam_u2f ];

    services.pcscd.enable = true;

    services.udev.packages = [ pkgs.yubikey-personalization ];

    # YubiKey is a USB HID device; guarantee the driver loads regardless of
    # what facter-modules derives from the hardware report.
    boot.kernelModules = [ "usbhid" ];

    # Feed this host's key mapping into the shared authfile built by user.nix.
    u2fMappings = cfg.u2fMapping;

    # user.nix owns security.pam.u2f — only add the lock screen here.
    # cosmic-greeter is excluded: the greeter doesn't relay pam_u2f prompts
    # reliably and a hang there locks the user out completely. cosmic-lock
    # (the screen locker) is sufficient for DE-level key protection.
    security.pam.services = { sddm.u2fAuth = true; cosmic-lock.u2fAuth = true; };
  };
}
