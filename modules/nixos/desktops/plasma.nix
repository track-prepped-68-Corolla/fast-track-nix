{ config, lib, pkgs, ... }:

################################################################################
# KDE PLASMA DESKTOP MODULE
################################################################################

let
  cfg = config.ft.desktop.plasma;
in
{
  options.ft.desktop.plasma = {
    enable = lib.mkEnableOption "KDE Plasma Desktop Environment" // {
      description = "Enables KDE Plasma 6 with X server, KDE Connect for device pairing, KWallet for credential storage, and a curated set of KDE apps (kate, kcalc, spectacle, partitionmanager, krdc). Elisa music player is excluded by default.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = lib.mkDefault true;
    services.desktopManager.plasma6.enable = lib.mkDefault true;
    programs.kdeconnect.enable = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      kdePackages.kate
      kdePackages.kcalc
      kdePackages.spectacle
      kdePackages.partitionmanager
      kdePackages.krdc
    ];

    environment.plasma6.excludePackages = with pkgs.kdePackages; [ elisa ];

    security.pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = lib.mkDefault true;
    };
  };
}
