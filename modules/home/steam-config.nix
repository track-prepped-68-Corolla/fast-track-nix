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
      description = "Enables steam-config-nix, which declaratively manages Steam launch options, per-game compatibility-tool overrides, and non-Steam game shortcuts. Configure individual games under programs.steam.config.apps and programs.steam.config.nonSteamApps once enabled. Home Manager counterpart of the NixOS ft.steamConfig module — use on standalone Home Manager systems or non-NixOS distros.";
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
