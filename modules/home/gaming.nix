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
      description = "Installs MangoHud, ProtonUp-Qt, SteamTinkerLaunch, Goverlay, Heroic, steam-tui, steamcmd, and steam-run into the user profile. Home Manager counterpart of the NixOS ft.gaming module's package set, independently useful on gaming-focused distros that already provide Steam (SteamOS, Bazzite) — Steam, GameMode, and gamescope remain NixOS-only since they require system-level privileges.";
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
