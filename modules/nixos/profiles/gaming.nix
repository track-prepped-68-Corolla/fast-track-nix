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
      description = "Sets up the Steam gaming stack: Steam itself plus GameMode, gamescope, MangoHud, Proton-GE, and a curated set of launchers and tools. Turn on ft.gaming.bigPicture to have Steam boot straight into Big Picture mode using a gamescope session.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Opens the firewall ports needed for Steam Remote Play and for sending games to other devices on the local network.";
    };

    gamescope = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Turns on gamescope, the lightweight compositor Steam uses to run games in their own window or display.";
      };

      hdr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Turns on HDR output in gamescope. Your display and GPU driver both need to support HDR for this to do anything.";
      };
    };

    controllerWake = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Lets the USB controller receivers listed in `usbIds` wake the system from suspend, using a udev rule that turns on their `power/wakeup`. Linux leaves wakeup off for anything that isn't a keyboard, so without this a receiver's remote-wakeup signal is ignored. The receiver's firmware must send that signal, and USB wake from S3 must be allowed in firmware/BIOS. Exempt from VM smoke tests (hardware-dependent).";
      };

      usbIds = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "[0-9a-f]{4}:[0-9a-f]{4}");
        default = [
          "28de:1304"
          "28de:1305"
        ];
        defaultText = lib.literalExpression ''[ "28de:1304" "28de:1305" ]'';
        description = "USB `vendor:product` IDs (lowercase hex) of the controller receivers allowed to wake the system. The defaults are Valve's Steam Controller Puck and Steam Machine internal receiver.";
      };
    };

    bigPicture = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Runs Steam in Big Picture mode inside a gamescope session, taking over the screen in place of the regular desktop session when you log in.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = lib.mkIf cfg.controllerWake.enable (
      lib.concatMapStrings (
        id:
        let
          parts = lib.splitString ":" id;
        in
        ''
          ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="${builtins.elemAt parts 0}", ATTR{idProduct}=="${builtins.elemAt parts 1}", TEST=="power/wakeup", ATTR{power/wakeup}="enabled"
        ''
      ) cfg.controllerWake.usbIds
    );

    programs = {
      gamemode.enable = lib.mkDefault true;

      gamescope = {
        # lib.mkOverride 900 sits between mkDefault (1001) and bare (100):
        # beats steam.nix's lib.mkDefault false, but consumers can still override
        # with a plain assignment without needing lib.mkForce
        enable = lib.mkOverride 900 cfg.gamescope.enable;
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
