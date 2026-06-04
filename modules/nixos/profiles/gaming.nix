{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# GAMING PROFILE MODULE
################################################################################

let
  cfg = config.ft.gaming;
in
{
  options.ft.gaming = {
    enable = lib.mkEnableOption "gaming stack" // {
      description = "Enables Steam with GameMode, gamescope, MangoHud, Proton-GE, and a curated set of launchers and tools. Set ft.gaming.bigPicture = true to boot Steam into Big Picture mode via a gamescope session.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for Steam Remote Play and local network game transfers.";
    };

    gamescope = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the gamescope micro-compositor.";
      };

      hdr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HDR output in gamescope. Requires an HDR-capable display and a supporting GPU driver.";
      };
    };

    bigPicture = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run Steam inside a gamescope session (Big Picture mode), replacing the desktop session on login.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      gamemode.enable = lib.mkDefault true;

      gamescope = {
        # plain assignment (priority 100) overrides steam.nix's lib.mkDefault false (priority 1001)
        # without causing a same-priority conflict; lib.mkDefault here would collide with it
        enable = cfg.gamescope.enable;
        capSysNice = lib.mkDefault true;
        args = lib.mkDefault (lib.optionals cfg.gamescope.hdr [ "--hdr-enabled" ]);
      };

      steam = {
        enable = lib.mkDefault true;
        remotePlay.openFirewall = lib.mkDefault cfg.openFirewall;
        dedicatedServer.openFirewall = lib.mkDefault cfg.openFirewall;
        localNetworkGameTransfers.openFirewall = lib.mkDefault cfg.openFirewall;
        gamescopeSession.enable = lib.mkDefault cfg.bigPicture;
        extraCompatPackages = lib.mkDefault [ pkgs.proton-ge-bin ];
      };
    };

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      steamtinkerlaunch
      goverlay
      heroic
      steam-tui
      steamcmd
      steam-run
    ];
  };
}
