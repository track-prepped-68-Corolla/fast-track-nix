{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# GAMING COMPANION TOOLS (Home Manager)
# ------------------------------------------------------------------------------
# Installs the gaming toolset (overlays, compatibility tooling, alternate
# launchers) into the user profile. Independent of the NixOS ft.gaming module
# — Steam, GameMode, and gamescope themselves require system-level privileges
# (setuid wrappers, polkit, firewall rules) that Home Manager cannot grant, so
# this module does not attempt to manage them. Intended for gaming-focused
# distros that already ship Steam out of the box (SteamOS, Bazzite) and just
# need the rest of the toolset layered on top.
################################################################################

let
  cfg = config.ft.gaming;
in
{
  options.ft.gaming = {
    enable = lib.mkEnableOption "gaming companion tools" // {
      description = "Installs a set of gaming companion tools into your user profile: MangoHud, ProtonUp-Qt, SteamTinkerLaunch, Goverlay, Heroic, steam-tui, steamcmd, and steam-run. This mirrors the package set from the NixOS `ft.gaming` module and is handy on its own for gaming-focused distros that already ship Steam, like SteamOS or Bazzite. Steam itself, GameMode, and gamescope stay NixOS-only, since they need system-level privileges this module can't grant.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkDefault (
      with pkgs;
      [
        mangohud
        protonup-qt
        steamtinkerlaunch
        goverlay
        heroic
        steam-tui
        steamcmd
        steam-run
      ]
    );
  };
}
