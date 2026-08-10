{
  lib,
  config,
  inputs,
  ...
}:

################################################################################
# STEAM CONFIG MODULE — declarative per-game Steam settings
################################################################################

let
  cfg = config.ft.steamConfig;
in
{
  imports = [ inputs.steam-config-nix.nixosModules.default ];

  options.ft.steamConfig = {
    enable = lib.mkEnableOption "declarative Steam per-game config" // {
      description = "Turns on steam-config-nix, which lets you declare Steam launch options, per-game compatibility-tool choices, and shortcuts for non-Steam games in your configuration instead of clicking through Steam's UI. Once enabled, configure individual games under programs.steam.config.apps and programs.steam.config.nonSteamApps.";
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
