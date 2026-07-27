{
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.ft.nixIndex;
in
{
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  options.ft.nixIndex = {
    enable = lib.mkEnableOption "nix-index with pre-built database and comma integration" // {
      default = true;
    };
    comma = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Turn on comma, which lets you run a command that isn't installed yet by looking it up via nix-index.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nix-index-database = {
      comma.enable = lib.mkDefault cfg.comma;
    };

    nix.settings = {
      extra-substituters = [ "https://nix-community.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Bg="
      ];
    };
  };
}
