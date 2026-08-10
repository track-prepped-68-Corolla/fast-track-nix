{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# NOCTALIA — QuickShell-based Wayland shell/bar, launched via Vicinae
#
# Exempt from the VM smoke test requirement: pulls in Noctalia's QuickShell/
# Qt6 stack (binary-cache-dependent), same exemption class as ft.vicinae.
################################################################################

let
  cfg = config.ft.noctalia;
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  options.ft.noctalia = {
    enable = lib.mkEnableOption "Noctalia shell" // {
      description = "Installs and runs Noctalia, a QuickShell-based Wayland shell/bar, kept running as a systemd user service. Meant to run inside a niri session (ft.niri, NixOS). Requires ft.vicinae.enable, since Vicinae is the launcher used in place of Noctalia's own built-in one — enable ft.niri (HM) alongside this to bind niri's launcher key to `vicinae toggle` automatically, and disable Noctalia's built-in launcher panel through its own settings. Configure appearance and behavior directly through `programs.noctalia.{settings,customPalettes}`, which Noctalia's own module provides. For the supporting NixOS-level services (NetworkManager, Bluetooth, UPower, power profiles), also enable the host's `ft.noctalia.enable` (NixOS).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.vicinae.enable;
        message = "ft.noctalia requires ft.vicinae.enable = true";
      }
    ];

    programs.noctalia = {
      enable = true;
      systemd.enable = lib.mkDefault true;
    };
  };
}
