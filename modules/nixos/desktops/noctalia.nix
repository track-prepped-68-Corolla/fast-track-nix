{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# NOCTALIA — supporting system services
#
# Noctalia itself (the shell process, its systemd user service, and its
# declarative settings) is run entirely through ft.noctalia in Home Manager.
# This module only pulls in the system services Noctalia's bar widgets need
# to show real data (network, Bluetooth, power) — pair it with ft.niri for
# a session to run it in.
#
# Exempt from the VM smoke test requirement: pulls in Noctalia's QuickShell/
# Qt6 stack (binary-cache-dependent), same exemption class as ft.vicinae.
################################################################################

let
  cfg = config.ft.noctalia;
in
{
  imports = [ inputs.noctalia.nixosModules.default ];

  options.ft.noctalia = {
    enable = lib.mkEnableOption "Noctalia supporting system services" // {
      description = "Turns on the NixOS-level services Noctalia (a QuickShell-based Wayland shell/bar, enabled per-user via ft.noctalia in Home Manager) needs for its widgets to function: NetworkManager, Bluetooth, UPower, and a power-profile daemon. NetworkManager and Bluetooth are already on by default via ft.core; this adds UPower and power-profiles-daemon on top.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.noctalia = {
      enable = lib.mkDefault true;
      recommendedServices.enable = lib.mkDefault true;
    };
  };
}
