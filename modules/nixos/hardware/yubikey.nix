{
  config,
  lib,
  pkgs,
  ...
}:

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
    environment.systemPackages = with pkgs; [
      yubikey-manager
      yubico-piv-tool
      pam_u2f
    ];

    services.pcscd.enable = true;

    services.udev.packages = [ pkgs.yubikey-personalization ];

    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
      sddm.u2fAuth = true;
      cosmic-greeter.u2fAuth = true;
      cosmic-lock.u2fAuth = true;
    };

    security.pam.u2f.settings = {
      cue = true;
      interactive = true;
      control = "sufficient";
      authfile = pkgs.writeText "u2f-mapping" cfg.u2fMapping;
    };
  };
}
