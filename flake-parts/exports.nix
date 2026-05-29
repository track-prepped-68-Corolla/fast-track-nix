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

    nixosModules.default =
      let
        diskoModule = inputs.Disko.nixosModules.disko;
        # Capture nixos-facter at flake-evaluation time for the same reason as
        # disko: avoids infinite recursion when inputs is provided via
        # _module.args rather than specialArgs (e.g. in NixOS VM smoke tests).
        facterModule = inputs.nixos-facter.nixosModules.facter;
      in
      {
        imports = [
          diskoModule
          facterModule
          (import ../modules/nixos)
        ];
      };

    # Standalone export for consumers who want only the imperative-package
    # escape hatch without importing the full framework.
    nixosModules.mullet = import ../modules/nixos/system/mullet.nix;

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
