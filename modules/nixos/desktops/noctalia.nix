{
  lib,
  config,
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
# programs.noctalia (NixOS) is provided natively by nixpkgs
# (nixos/modules/programs/wayland/noctalia.nix) — no import of the noctalia
# flake input's own nixosModules.default needed (or wanted: it declares the
# same option path and would conflict). The Home Manager side still needs
# ft.noctalia's own import, since home-manager hasn't picked up an equivalent
# module yet.
#
# Exempt from the VM smoke test requirement: pulls in Noctalia's QuickShell/
# Qt6 stack (binary-cache-dependent), same exemption class as ft.vicinae.
################################################################################

let
  cfg = config.ft.noctalia;
in
{
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
