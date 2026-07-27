{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# VICINAE — binary cache + input-server capability wrapper
#
# Exempt from the VM smoke test requirement: pulls in the full Qt6/C++ build
# (binary-cache-dependent), same exemption class as ft.plasmaBigscreen.
################################################################################

let
  cfg = config.ft.vicinae;
in
{
  options.ft.vicinae = {
    enable = lib.mkEnableOption "Vicinae binary cache" // {
      description = "Registers the upstream vicinae.cachix.org binary cache, so the Vicinae launcher (ft.vicinae.enable in Home Manager) doesn't have to compile its Qt6/C++ stack from source.";
    };

    inputServer = {
      enable = lib.mkEnableOption "Vicinae input-server capability wrapper" // {
        description = "Wraps vicinae-input-server with cap_dac_override (via security.wrappers), giving it raw input-device access for Vicinae's global-hotkey and keystroke-injection features. This bypasses the wrapped binary's normal file-permission checks, so leave it disabled if Vicinae is only ever launched through a compositor-bound shortcut (e.g. a KWin global shortcut running `vicinae toggle`).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      extra-substituters = lib.mkDefault [ "https://vicinae.cachix.org" ];
      extra-trusted-public-keys = lib.mkDefault [
        "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      ];
    };

    security.wrappers.vicinae-input-server = lib.mkIf cfg.inputServer.enable {
      source = lib.mkDefault "${
        inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default
      }/libexec/vicinae/vicinae-input-server";
      capabilities = lib.mkDefault "cap_dac_override+ep";
      owner = lib.mkDefault "root";
      group = lib.mkDefault "root";
    };
  };
}
