{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;

      # Evaluate NixOS modules via the full nixosSystem so upstream imports
      # (disko, microvm, sops-nix, etc.) can declare their options freely.
      # Pinned to x86_64-linux — option declarations don't vary by arch, and
      # using `system` from perSystem would evaluate NixOS modules under darwin
      # targets where they don't apply.
      # nixos-facter-modules/system.nix is disabled for the same reason as in
      # lib.vmTestBase: it unconditionally sets nixpkgs.hostPlatform, which
      # conflicts with the system argument passed here.
      nixosEval = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          inputs.self.nixosModules.default
          { disabledModules = [ "${inputs.nixos-facter-modules}/modules/nixos/system.nix" ]; }
        ];
        specialArgs = { inherit inputs; };
      };

      # Evaluate Home Manager modules via the full homeManagerConfiguration so
      # upstream imports (sops-nix, stylix, etc.) resolve without errors.
      # The stub module satisfies two required options that have no defaults:
      #   home.username       — required by HM and referenced in ft.dotfiles.path
      #                         default, which would otherwise force config eval
      #                         and cascade through the HM nixpkgs module.
      #   ft.core.stateVersion — required by home-core.nix; ft.core.enable
      #                          defaults to true so its config block always runs
      #                          and sets home.stateVersion = cfg.stateVersion.
      homeEval = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          inputs.self.homeManagerModules.default
          {
            home.username = "docs-eval";
            ft.core.stateVersion = "25.05";
          }
        ];
        extraSpecialArgs = { inherit inputs; };
      };

      ftOptions = options: lib.filterAttrs (n: _: n == "ft") options;

      # Docs packages: permissive — always produce output even if descriptions
      # are missing (so the generate workflow doesn't block on style gaps).
      mkDocs = options: pkgs.nixosOptionsDoc {
        options = ftOptions options;
        warningsAreErrors = false;
      };

      # Strict evaluation used for checks — fails nix flake check if any ft.*
      # option is missing a description, enforcing the module authoring rules.
      mkStrictDocs = options: pkgs.nixosOptionsDoc {
        options = ftOptions options;
        warningsAreErrors = true;
      };
    in
    {
      packages = {
        module-docs-nixos = (mkDocs nixosEval.options).optionsCommonMark;
        module-docs-home = (mkDocs homeEval.options).optionsCommonMark;
      };

      checks = {
        option-docs-nixos = (mkStrictDocs nixosEval.options).optionsJSON;
        option-docs-home = (mkStrictDocs homeEval.options).optionsJSON;
      };
    };
}
