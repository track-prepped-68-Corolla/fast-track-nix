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
      # ftUserPath is normally injected by the generator (flake-parts/generator.nix)
      # via extraSpecialArgs; this standalone eval has no consumer users/<name>
      # directory to derive it from, so it's stubbed to null here — same value a
      # consumer would get using homeManagerModules.default directly outside the
      # generator. The module system requires every declared module argument to
      # resolve to something even when unused, so this must be passed explicitly
      # rather than relying on modules/home/mullet.nix's own `ftUserPath ? null`.
      homeEval = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          inputs.self.homeManagerModules.default
          {
            home.username = "docs-eval";
            ft.core.stateVersion = "25.05";
          }
        ];
        extraSpecialArgs = {
          inherit inputs;
          ftUserPath = null;
        };
      };

      ftOptions = options: lib.filterAttrs (n: _: n == "ft") options;

      # Docs packages: permissive — always produce output even if descriptions
      # are missing (so the generate workflow doesn't block on style gaps).
      mkDocs =
        options:
        pkgs.nixosOptionsDoc {
          options = ftOptions options;
          warningsAreErrors = false;
        };

      # Strict evaluation used for checks — fails nix flake check if any ft.*
      # option is missing a description, enforcing the module authoring rules.
      mkStrictDocs =
        options:
        pkgs.nixosOptionsDoc {
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

        # Fails nix flake check if modules/{nixos,home}/README.md drifts from
        # what nixosOptionsDoc actually generates for the current module tree
        # (e.g. a module is renamed/removed but the committed README isn't
        # regenerated). Mirrors the diff style of the `format` check.
        #
        # "Declared by" links embed the store-path hash of inputs.self itself
        # (file:///nix/store/<hash>-source/modules/...). That hash changes
        # whenever flake.lock is rewritten in-session — which CI's "Resolve
        # flake inputs" step does unconditionally before running this check —
        # even though nothing under modules/ actually changed. Both sides are
        # normalized to strip store-path hashes before diffing so the check
        # tracks real content drift instead of flake-lock churn.
        docs-fresh =
          pkgs.runCommand "docs-fresh-check"
            {
              nativeBuildInputs = [
                pkgs.diffutils
                pkgs.gnused
              ];
              nixosReadme = (mkDocs nixosEval.options).optionsCommonMark;
              homeReadme = (mkDocs homeEval.options).optionsCommonMark;
            }
            ''
              normalize() {
                sed -E 's#/nix/store/[0-9a-z]{32}-[^/[:space:])]*#/nix/store/HASH-NAME#g' "$1"
              }

              fail=0
              if ! diff -q <(normalize "$nixosReadme") <(normalize ${inputs.self}/modules/nixos/README.md); then
                echo "modules/nixos/README.md is stale."
                fail=1
              fi
              if ! diff -q <(normalize "$homeReadme") <(normalize ${inputs.self}/modules/home/README.md); then
                echo "modules/home/README.md is stale."
                fail=1
              fi
              if [ "$fail" -ne 0 ]; then
                echo "Run the 'Generate Module READMEs' workflow (workflow_dispatch) to regenerate."
                exit 1
              fi
              touch $out
            '';
      };
    };
}
