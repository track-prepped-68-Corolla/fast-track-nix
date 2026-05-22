{ inputs, ... }:
{
  flake = {
    lib.mkFlake = consumerInputs: import ./_generator.nix (inputs // consumerInputs);
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
