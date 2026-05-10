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
    enable = lib.mkEnableOption "KeePassXC as the primary keyring and secret service";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      keepassxc
    ];

    services.gnome.gnome-keyring.enable = lib.mkForce false;
  };
}
