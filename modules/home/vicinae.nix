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
      description = "Installs and runs the Vicinae launcher (app search, clipboard history, emoji picker, calculator, Raycast-compatible extensions) as a systemd user service. Exposes `programs.vicinae.{extensions,themes,settings}` (vicinae's own module) as the configuration surface — set those directly in this user's config. Pair with the host's `ft.vicinae.inputServer.enable` (NixOS) for global-hotkey and keystroke-injection support.";
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
