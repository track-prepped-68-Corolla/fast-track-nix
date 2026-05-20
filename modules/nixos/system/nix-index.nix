{
  lib,
  config,
  inputs,
  ...
}:

{
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  options.ft.programs.nixIndex = {
    enable = lib.mkEnableOption "nix-index with pre-built database and comma integration" // {
      default = true;
    };
    comma = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable comma — run uninstalled commands via nix-index.";
    };
  };

  config = lib.mkIf config.ft.programs.nixIndex.enable {
    programs.nix-index-database = {
      comma.enable = config.ft.programs.nixIndex.comma;
    };

    nix.settings = {
      extra-substituters = [ "https://nix-community.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Bg="
      ];
    };
  };
}
