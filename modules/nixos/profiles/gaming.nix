{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

################################################################################
# UNIVERSAL GAMING PROFILE MODULE
################################################################################

let
  cfg = config.ft.profiles.gaming;
in
{
  imports = [
    inputs.jovian-nixos.nixosModules.default
  ];

  options.ft.profiles.gaming = {
    enable = lib.mkEnableOption "Universal Gaming Profile" // {
      description = "Enables a complete gaming stack: Steam with LAN/remote-play firewall rules, GameMode, MangoHud, Proton tooling (protonup-qt, steamtinkerlaunch), and Jovian-NixOS integration. Set `ft.profiles.gaming.enableLeanbackUI = true` to boot directly into Steam Big Picture with Decky Loader.";
    };

    enableLeanbackUI = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Steam Deck-like UI (boots directly into Steam Big Picture).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.mainuser;
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
      description = "GPU vendor for hardware optimizations (amd, intel, nvidia).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      steamtinkerlaunch
      goverlay
      heroic
    ];

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = false;
    };

    jovian.steam = {
      enable = true;
      autoStart = cfg.enableLeanbackUI;
      user = cfg.user;
      desktopSession = lib.mkIf cfg.enableLeanbackUI cfg.desktopEnvironment;
    };

    jovian.decky-loader.enable = cfg.enableLeanbackUI;
    jovian.hardware.has.amd.gpu = (cfg.gpuVendor == "amd");
  };
}
