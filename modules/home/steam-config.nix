{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# STEAM CONFIG MODULE (Home Manager) — declarative per-game Steam settings
################################################################################
#
# Home Manager counterpart of the NixOS ft.steamConfig module. Useful on
# standalone Home Manager systems or non-NixOS distros that already ship
# Steam (SteamOS, Bazzite) and just need the per-game config layer.

let
  cfg = config.ft.steamConfig;
in
{
  imports = [ inputs.steam-config-nix.homeModules.default ];

  options.ft.steamConfig = {
    enable = lib.mkEnableOption "declarative Steam per-game config" // {
      description = "Lets you manage Steam's per-game settings declaratively — launch options, compatibility tool overrides, and shortcuts for non-Steam games — instead of clicking through Steam's own settings. Once enabled, configure individual games under `programs.steam.config.apps` and `programs.steam.config.nonSteamApps`. This is the Home Manager counterpart of the NixOS `ft.steamConfig` module, meant for standalone Home Manager systems or non-NixOS distros.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam.config = {
      enable = lib.mkDefault true;
      # Writing config files while Steam holds them open risks corruption;
      # close it (without killing any running game) before applying changes.
      onSteamRunning = lib.mkDefault "close";
    };
  };
}
