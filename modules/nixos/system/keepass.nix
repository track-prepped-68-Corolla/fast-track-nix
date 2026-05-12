{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.keepass;
in
{
  options.ft.keepass = {
    enable = lib.mkEnableOption "KeePassXC as the primary keyring and secret service" // {
      description = "Installs KeePassXC and force-disables the GNOME Keyring so KeePassXC becomes the sole secret storage backend. Useful on COSMIC or hybrid DE setups where GNOME Keyring's auto-unlock would bypass hardware key authentication.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      keepassxc
    ];

    services.gnome.gnome-keyring.enable = lib.mkForce false;
  };
}
