{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      statixConfig = inputs.self + "/statix.toml";
      configArg = pkgs.lib.optionalString (builtins.pathExists statixConfig) "--config ${statixConfig}";

      # Eval-only regression test for /src's permission hardening
      # (disko-btrfs.nix): ft.diskBtrfs is hardware-dependent and exempt from
      # the ft-testing VM smoke-test suite (no real/virtual block device in
      # the eval sandbox), so this checks the generated config's shape
      # directly instead of exercising it end-to-end. Catches a future
      # refactor silently dropping the ACL, the repair pass, the ordering, the
      # mountpoint guard, or the git safe.directory override — not whether any
      # of it actually works on real hardware.
      srcHardeningConfig = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          inputs.Disko.nixosModules.disko
          ../modules/nixos/hardware/disko-btrfs.nix
          { ft.diskBtrfs.enable = true; }
        ];
      };
      srcAclUnit = srcHardeningConfig.config.systemd.services.ftSrcDefaultAcl;

      # Eval-only regression test for ft.gitops.autoPromote: the real behavior
      # (comin actually running the hook after a deployment) is explicitly out
      # of scope for the ft-testing gitops VM test too — a real deploy needs
      # comin to rebuild this machine's nixosConfiguration *inside* the VM
      # sandbox, which isn't feasible there either. This only checks that the
      # option correctly wires (or doesn't wire) services.comin's
      # postDeploymentCommand.
      mkGitopsConfig =
        autoPromote:
        inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ../modules/nixos/services/gitops.nix
            {
              ft.gitops = {
                enable = true;
                remotes = [
                  {
                    name = "test-remote";
                    url = "file:///dev/null";
                  }
                ];
                autoPromote.enable = autoPromote;
              };
            }
          ];
        };
    in
    {
      checks = {
        srcDefaultAcl =
          assert lib.hasInfix "setfacl" srcAclUnit.serviceConfig.ExecStart;
          assert lib.hasInfix "-d -m g:wheel:rwx /src" srcAclUnit.serviceConfig.ExecStart;
          assert lib.hasInfix "chown" srcAclUnit.serviceConfig.ExecStart;
          assert lib.hasInfix "-R root:wheel /src" srcAclUnit.serviceConfig.ExecStart;
          assert lib.hasInfix "chmod" srcAclUnit.serviceConfig.ExecStart;
          assert lib.hasInfix "-R g+rwX /src" srcAclUnit.serviceConfig.ExecStart;
          assert lib.hasInfix "g+s" srcAclUnit.serviceConfig.ExecStart;
          assert srcAclUnit.unitConfig.ConditionPathIsMountPoint == "/src";
          assert lib.elem "local-fs.target" srcAclUnit.after;
          assert srcAclUnit.serviceConfig.Type == "oneshot";
          assert lib.hasInfix "directory = *" srcHardeningConfig.config.environment.etc."gitconfig".text;
          pkgs.runCommand "src-default-acl-check" { } "touch $out";

        gitopsAutoPromote =
          assert (mkGitopsConfig true).config.services.comin.postDeploymentCommand != null;
          assert (mkGitopsConfig false).config.services.comin.postDeploymentCommand == null;
          pkgs.runCommand "gitops-auto-promote-check" { } "touch $out";

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
