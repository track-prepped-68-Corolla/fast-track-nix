{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# KDE PLASMA DESKTOP MODULE
################################################################################

let
  cfg = config.ft.plasma;
in
{
  options.ft.plasma = {
    enable = lib.mkEnableOption "KDE Plasma Desktop Environment" // {
      description = "Turns on KDE Plasma 6 with SDDM as the login screen and the X server enabled, along with KDE Connect for pairing with phones and other devices, KWallet for storing credentials, and a curated set of KDE apps (Kate, KCalc, Spectacle, Partition Manager, and KRDC). The Elisa music player is left out by default.";
    };
  };

  config = lib.mkIf cfg.enable {
    # nixpkgs' plasma6 module sets services.displayManager.defaultSession =
    # mkDefault "plasma". If another desktop module enabled alongside this
    # one — e.g. ft.niri, whose upstream module defends itself the same way
    # with mkDefault "niri" — also claims defaultSession via mkDefault, the
    # two same-priority defaults conflict and nix flake check/switch fails
    # outright, since neither wins automatically. A plain assignment already
    # outranks both mkDefaults, so no mkForce needed — pick one manually in
    # the consuming machine's config when running ft.plasma alongside
    # another desktop:
    #
    #   services.displayManager.defaultSession = "plasma"; # or "niri"
    services = {
      xserver.enable = lib.mkDefault true;
      desktopManager.plasma6.enable = lib.mkDefault true;
      displayManager.sddm.enable = lib.mkDefault true;
    };

    programs.kdeconnect.enable = lib.mkDefault true;

    environment = {
      systemPackages = with pkgs; [
        kdePackages.kate
        kdePackages.kcalc
        kdePackages.spectacle
        kdePackages.partitionmanager
        kdePackages.krdc
      ];

      plasma6.excludePackages = with pkgs.kdePackages; [ elisa ];
    };

    security.pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = lib.mkDefault true;
    };
  };
}
