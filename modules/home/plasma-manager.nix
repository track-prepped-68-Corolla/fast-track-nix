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
      description = "Enables plasma-manager so KDE Plasma settings (panels, shortcuts, kwinrc keys, etc.) are declared in Home Manager via `programs.plasma.*` instead of mutated through the Plasma GUI.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma.enable = lib.mkDefault true;
  };
}
