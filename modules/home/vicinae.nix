{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# VICINAE — native Raycast-compatible launcher
################################################################################

let
  cfg = config.ft.vicinae;
in
{
  imports = [ inputs.vicinae.homeManagerModules.default ];

  options.ft.vicinae = {
    enable = lib.mkEnableOption "Vicinae launcher" // {
      description = "Installs and runs Vicinae, a Raycast-compatible app launcher with app search, clipboard history, an emoji picker, a calculator, and support for Raycast extensions, kept running as a systemd user service. Configure it directly through `programs.vicinae.{extensions,themes,settings}`, which Vicinae's own module provides. For global hotkeys and keystroke injection, also enable the host's `ft.vicinae.inputServer.enable` (NixOS).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vicinae = {
      enable = true;
      systemd = {
        enable = lib.mkDefault true;
        autoStart = lib.mkDefault true;
      };
    };
  };
}
