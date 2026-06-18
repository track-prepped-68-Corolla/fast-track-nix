{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# PLASMA BIGSCREEN TV SHELL MODULE
################################################################################

let
  cfg = config.ft.plasmaBigscreen;
in
{
  options.ft.plasmaBigscreen = {
    enable = lib.mkEnableOption "Plasma Bigscreen TV shell" // {
      description = "Installs kdePackages.plasma-bigscreen and registers its plasma-bigscreen-wayland session via services.displayManager.sessionPackages. Exempt from the VM smoke test requirement: pulls in qtwebengine and the full KDE Frameworks stack (binary-cache-dependent), and its primary input path (HDMI-CEC) cannot be exercised inside a VM (hardware-dependent).";
    };

    cecSupport = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Loads the cec kernel module and installs libcec and v4l-utils so a TV remote can drive Plasma Bigscreen over HDMI-CEC.";
    };

    defaultSession = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Makes plasma-bigscreen-wayland the default SDDM session, and therefore the session autologin starts, instead of merely adding it as a selectable option alongside any other configured session.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager = {
      sddm = {
        enable = lib.mkDefault true;
        wayland.enable = lib.mkDefault true;
      };
      sessionPackages = [ pkgs.kdePackages.plasma-bigscreen ];
      defaultSession = lib.mkIf cfg.defaultSession (lib.mkDefault "plasma-bigscreen-wayland");
    };

    boot.kernelModules = lib.optional cfg.cecSupport "cec";

    environment.systemPackages = lib.optionals cfg.cecSupport [
      pkgs.libcec
      pkgs.v4l-utils
    ];
  };
}
