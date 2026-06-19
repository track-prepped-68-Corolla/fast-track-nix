{ inputs, ... }:
let
  # The canonical merge: framework inputs on the left, consumer inputs on the
  # right so the consumer wins on any collision.  Every place that needs the
  # merged set calls this one function — changes here propagate everywhere.
  mergeInputs = consumerInputs: inputs // consumerInputs;
in
{
  flake = {
    lib = {
      inherit mergeInputs;

      # Consumer entry point — delegates to the flake-parts generator.
      # Usage in a consumer's flake.nix:
      #   outputs = inputs @ { ft-home, ... }: ft-home.lib.mkFlake inputs;
      mkFlake =
        consumerInputs:
        let
          mergedInputs = mergeInputs consumerInputs;
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

      # Wraps pkgs.testers.runNixOSTest so every test node receives the same
      # merged input set — via specialArgs — that real NixOS machines get from
      # the generator.  Bind it once at the top of a test file:
      #
      #   mkTest = inputs.ft-framework.lib.mkVmTest inputs;
      mkVmTest =
        consumerInputs:
        let
          mergedInputs = mergeInputs consumerInputs;
          pkgs = mergedInputs.nixpkgs.legacyPackages.x86_64-linux;
        in
        spec:
        pkgs.testers.runNixOSTest (
          mergedInputs.nixpkgs.lib.recursiveUpdate spec {
            node.specialArgs.inputs = mergedInputs;
          }
        );

      # Base NixOS module for VM smoke test nodes.  Imports the same framework
      # module hub that real machines use (nixosModules.default) and disables
      # modules that are incompatible with the NixOS test sandbox:
      #
      #   disko-btrfs  — hardware-dependent disk layout; no real block devices
      #                  in a VM.
      #   gaming       — Steam closure is too heavyweight for CI VMs.
      #   nixos-facter-modules/system.nix — always defines nixpkgs.hostPlatform
      #                  (even when ft.facter.enable = false, because facter.nix
      #                  imports it unconditionally) which conflicts with the test
      #                  sandbox's read-only pkgs mode.
      #
      # Usage:
      #   baseConfig = { ... }: {
      #     imports = [ (inputs.ft-framework.lib.vmTestBase inputs) ];
      #     ft.core.stateVersion = "25.05";
      #   };
      vmTestBase =
        consumerInputs:
        let
          mergedInputs = mergeInputs consumerInputs;
        in
        { ... }: {
          imports = [ inputs.self.nixosModules.default ];
          disabledModules = [
            "${inputs.self}/modules/nixos/hardware/disko-btrfs.nix"
            "${inputs.self}/modules/nixos/profiles/gaming.nix"
            "${mergedInputs.nixos-facter-modules}/modules/nixos/system.nix"
          ];
        };
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

    nixosModules.mullet = import ../modules/nixos/apps/mullet.nix;

    homeManagerModules.default = import ../modules/home;
  };

  perSystem =
    { pkgs, ... }:
    {
      packages = {
        inherit (pkgs) nixfmt deadnix;

        # Shell test suite for the bundled ft just-recipes: shellcheck +
        # bats (unit + integration). Exposed as a package (not a flake check)
        # so it stays out of the gating `nix flake check` and is run on demand
        # via the Shell Tests workflow_dispatch job or `nix build .#shell-tests`.
        shell-tests =
          let
            src = pkgs.lib.fileset.toSource {
              root = ../.;
              fileset = pkgs.lib.fileset.unions [
                ../scripts
                ../tests
                ../flake.nix
              ];
            };
          in
          pkgs.stdenvNoCC.mkDerivation {
            name = "ft-shell-tests";
            inherit src;
            nativeBuildInputs = with pkgs; [
              bats
              shellcheck
              just
              jq
              git
              gnused
              gnugrep
              gawk
              coreutils
            ];
            dontConfigure = true;
            dontBuild = true;
            doCheck = true;
            checkPhase = ''
              runHook preCheck
              export HOME="$TMPDIR"
              export GIT_CONFIG_NOSYSTEM=1
              export GIT_CONFIG_GLOBAL=/dev/null
              bash tests/shell/run.sh
              runHook postCheck
            '';
            installPhase = "touch $out";
          };

        default =
          let
            scriptsDir = ../scripts;
          in
          pkgs.writeShellApplication {
            name = "ft";
            runtimeInputs = with pkgs; [
              just
              glow
              nh
              git
              nvd
              delta
              trufflehog
            ];
            text = ''
              export FT_REPO="''${FT_REPO:-$(pwd)}"
              exec just --justfile "${scriptsDir}/ft.just" --working-directory "$FT_REPO" "$@"
            '';
          };
      };
    };
}
