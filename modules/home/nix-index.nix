{
  config,
  lib,
  inputs,
  ...
}:

################################################################################
# NIX-INDEX MODULE (Home Manager)
# ------------------------------------------------------------------------------
# Installs nix-index with a pre-built database and comma into the user
# profile. Independent of the NixOS ft.nixIndex module — trusts the
# nix-community.cachix.org substituter itself via Home Manager's own
# nix.settings, since standalone Home Manager systems and non-NixOS distros
# (SteamOS, Bazzite) typically run Nix single-user, where the user is already
# trusted and there is no system-level ft.nixIndex to rely on.
################################################################################

let
  cfg = config.ft.nixIndex;
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  options.ft.nixIndex = {
    enable = lib.mkEnableOption "nix-index with pre-built database and comma integration" // {
      default = true;
      description = "Installs nix-index with a pre-built database and comma into the user profile. Home Manager counterpart of the NixOS ft.nixIndex module, independently useful on standalone Home Manager systems or non-NixOS distros (SteamOS, Bazzite).";
    };

    comma = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable comma — run uninstalled commands via nix-index.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nix-index-database.comma.enable = lib.mkDefault cfg.comma;

    nix.settings = {
      extra-substituters = lib.mkDefault [ "https://nix-community.cachix.org" ];
      extra-trusted-public-keys = lib.mkDefault [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Bg="
      ];
    };
  };
}
