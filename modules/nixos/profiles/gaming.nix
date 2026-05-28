{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# UNIVERSAL GAMING PROFILE MODULE
# Requires the host to import inputs.jovian-nixos.nixosModules.default.
################################################################################

let
  cfg = config.ft.gaming;
in
{
  meta.description = "Enables a complete gaming stack: Steam with LAN/remote-play firewall rules, GameMode, MangoHud, Proton tooling (protonup-qt, steamtinkerlaunch), and Jovian-NixOS integration. Set ft.gaming.enableLeanbackUI = true to boot directly into Steam Big Picture with Decky Loader.";

  options.ft.gaming = {
    enableLeanbackUI = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Steam Deck-like UI (boots directly into Steam Big Picture).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.ft.user.mainUser;
      description = "The username for the gaming session.";
    };

    desktopEnvironment = lib.mkOption {
      type = lib.types.str;
      default = "plasma";
      description = "Desktop environment for gaming sessions (e.g., plasma, gnome).";
    };

    gpuVendor = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" "nvidia" ];
      default = "amd";
      description = "GPU vendor for hardware optimizations.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      gamemode.enable = true;
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        gamescopeSession.enable = false;
      };
    };

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      steamtinkerlaunch
      goverlay
      heroic
    ];

    jovian = {
      steam = {
        enable = true;
        autoStart = cfg.enableLeanbackUI;
        inherit (cfg) user;
        desktopSession = lib.mkIf cfg.enableLeanbackUI cfg.desktopEnvironment;
      };
      decky-loader.enable = cfg.enableLeanbackUI;
      hardware.has.amd.gpu = cfg.gpuVendor == "amd";
    };
  };
}
