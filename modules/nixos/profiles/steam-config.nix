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
      description = "Enables steam-config-nix, which declaratively manages Steam launch options, per-game compatibility-tool overrides, and non-Steam game shortcuts. Configure individual games under programs.steam.config.apps and programs.steam.config.nonSteamApps once enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam.config = {
      enable = lib.mkDefault true;
      # Writing config files while Steam holds them open risks corruption.
      closeSteam = lib.mkDefault true;
    };
  };
}
