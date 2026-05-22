{ inputs, ... }:
{
  flake = {
    lib.mkFlake =
      consumerInputs:
      let
        mergedInputs = inputs // consumerInputs;
      in
      mergedInputs.flake-parts.lib.mkFlake { inputs = mergedInputs; } {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
        ];
        imports = [
          ./generator.nix
          ./checks.nix
          ./formatter.nix
        ];
      };

    nixosModules.default = import ../modules/nixos;
    homeManagerModules.default = import ../modules/home;
  };

  perSystem =
    { pkgs, ... }:
    {
      packages = {
        inherit (pkgs) nixfmt deadnix;
      };
    };
}
