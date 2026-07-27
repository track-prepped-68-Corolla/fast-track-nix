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
      description = "Installs KeePassXC and turns off the GNOME Keyring so KeePassXC is the only place secrets are stored. This matters on desktops that mix components from different environments, where GNOME Keyring's auto-unlock could otherwise bypass your hardware key authentication.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ keepassxc ];
    services.gnome.gnome-keyring.enable = lib.mkForce false;
  };
}
