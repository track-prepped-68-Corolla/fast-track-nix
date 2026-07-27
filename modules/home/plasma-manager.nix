{
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.ft.plasmaManager;
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
  ];

  options.ft.plasmaManager = {
    enable = lib.mkEnableOption "declarative KDE Plasma settings via plasma-manager" // {
      description = "Lets you set KDE Plasma preferences — panels, keyboard shortcuts, window-manager settings, and more — directly in your Home Manager config through `programs.plasma.*`, instead of clicking through Plasma's settings app.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.enable = lib.mkDefault true;
  };
}
