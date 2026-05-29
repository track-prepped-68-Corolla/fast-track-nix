{
  lib,
  config,
  inputs,
  ...
}:
{
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  meta.description = "Enables nix-index with a pre-built database (no local indexing required) and comma integration for running uninstalled commands on demand.";

  options.ft."nix-index" = {
    comma = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable comma — run uninstalled commands via nix-index.";
    };
  };

  config = lib.mkIf config.ft."nix-index".enable {
    programs.nix-index-database = {
      comma.enable = config.ft."nix-index".comma;
    };

    nix.settings = {
      extra-substituters = [ "https://nix-community.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Bg="
      ];
    };
  };
}
