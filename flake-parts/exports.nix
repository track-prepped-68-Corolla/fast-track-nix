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

    # Capture disko and microvm host modules in the closure at flake-evaluation
    # time so that framework modules never need to reference inputs inside an
    # `imports` list.  Accessing inputs inside `imports` causes infinite
    # recursion when inputs is provided via _module.args rather than specialArgs
    # (e.g. in NixOS VM smoke tests).
    nixosModules.default =
      let
        diskoModule = inputs.Disko.nixosModules.disko;
        microvmHostModule = inputs.microvm.nixosModules.host;
      in
      {
        imports = [
          diskoModule
          microvmHostModule
          (import ../modules/nixos)
        ];
      };

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
