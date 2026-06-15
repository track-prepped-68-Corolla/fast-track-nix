{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      lib = inputs.nixpkgs.lib;

      # Evaluate NixOS modules via the full nixosSystem so upstream imports
      # (disko, microvm, sops-nix, etc.) can declare their options freely.
      # nixos-facter-modules/system.nix is disabled for the same reason as in
      # lib.vmTestBase: it unconditionally sets nixpkgs.hostPlatform, which
      # conflicts with the system argument passed here.
      nixosEval = lib.nixosSystem {
        inherit system;
        modules = [
          inputs.self.nixosModules.default
          { disabledModules = [ "${inputs.nixos-facter-modules}/modules/nixos/system.nix" ]; }
        ];
        specialArgs = { inherit inputs; };
      };

      # Evaluate Home Manager modules via the full homeManagerConfiguration so
      # upstream imports (sops-nix, stylix, etc.) resolve without errors.
      homeEval = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ inputs.self.homeManagerModules.default ];
        extraSpecialArgs = { inherit inputs; };
      };

      ftOptions = options: lib.filterAttrs (n: _: n == "ft") options;
      mkDocs = options: pkgs.nixosOptionsDoc { options = ftOptions options; };
    in
    lib.optionalAttrs pkgs.stdenv.isLinux {
      packages = {
        module-docs-nixos = (mkDocs nixosEval.options).optionsCommonMark;
        module-docs-home = (mkDocs homeEval.options).optionsCommonMark;
      };
    };
}
