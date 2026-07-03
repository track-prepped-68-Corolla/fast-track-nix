{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      statixConfig = inputs.self + "/statix.toml";
      configArg = pkgs.lib.optionalString (builtins.pathExists statixConfig) "--config ${statixConfig}";

      # Eval-only regression test for the /src default ACL (disko-btrfs.nix):
      # ft.diskBtrfs is hardware-dependent and exempt from the ft-testing VM
      # smoke-test suite (no real/virtual block device in the eval sandbox),
      # so this checks the generated systemd unit's shape directly instead of
      # exercising it end-to-end. Catches a future refactor silently dropping
      # the ACL, the ordering, or the mountpoint guard — not whether setfacl
      # actually works on real hardware.
      srcAclUnit =
        (inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.Disko.nixosModules.disko
            ../modules/nixos/hardware/disko-btrfs.nix
            { ft.diskBtrfs.enable = true; }
          ];
        }).config.systemd.services.ftSrcDefaultAcl;
    in
    {
      checks = {
        srcDefaultAcl =
          assert lib.hasInfix "setfacl" srcAclUnit.serviceConfig.ExecStart;
          assert lib.hasInfix "-d -m g:wheel:rwx /src" srcAclUnit.serviceConfig.ExecStart;
          assert srcAclUnit.unitConfig.ConditionPathIsMountPoint == "/src";
          assert lib.elem "local-fs.target" srcAclUnit.after;
          assert srcAclUnit.serviceConfig.Type == "oneshot";
          pkgs.runCommand "src-default-acl-check" { } "touch $out";
        format =
          pkgs.runCommand "format-check"
            {
              nativeBuildInputs = with pkgs; [
                nixfmt
                deadnix
                findutils
                diffutils
              ];
            }
            ''
              cp -r ${inputs.self}/. ref
              cp -r ${inputs.self}/. src
              find src \( -type f -o -type d \) -exec chmod u+w {} +
              find src -type f -name "*.nix" | sort | xargs -r nixfmt
              # deadnix runs twice: removing a dead binding can expose another
              # binding that was only referenced by the removed one.  A single
              # pass is not guaranteed to be idempotent.
              find src -type f -name "*.nix" | sort | xargs -r deadnix --edit
              find src -type f -name "*.nix" | sort | xargs -r deadnix --edit
              if ! diff -r -q src ref; then
                echo "Some Nix files need formatting."
                echo "Run: nixfmt <file> && deadnix --edit <file>"
                exit 1
              fi
              touch $out
            '';

        lint =
          pkgs.runCommand "statix-check"
            {
              nativeBuildInputs = [ pkgs.statix ];
            }
            ''
              cp -r ${inputs.self}/. .
              statix check . ${configArg}
              touch $out
            '';
      };
    };
}
