# Exercises the ft.gitWorkflow commit-msg hook against real fixture messages.
# Pure userspace CLI behaviour (lefthook + conform) has no systemd/kernel/
# hardware dependency, so this builds the hook via a standalone Home Manager
# configuration and runs it directly — no NixOS VM needed.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      hm = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs;
        };
        modules = [
          ../modules/home
          {
            home = {
              username = "tester";
              homeDirectory = "/home/tester";
            };
            ft.core.stateVersion = "25.05";
            ft.gitWorkflow.enable = true;
          }
        ];
      };
      commitMsgHook = hm.config.home.file.".config/git/hooks/commit-msg".source;
    in
    {
      checks.git-workflow-conform =
        pkgs.runCommand "git-workflow-conform-check"
          {
            nativeBuildInputs = [ pkgs.git ];
          }
          ''
            export HOME="$TMPDIR"
            mkdir repo && cd repo
            git init -q

            echo 'not a conventional commit' > bad-msg
            set +e
            ${commitMsgHook} bad-msg
            badStatus=$?
            set -e
            echo "commit-msg hook exit status for bad-msg: $badStatus"
            if [ "$badStatus" -eq 0 ]; then
              echo "expected commit-msg hook to reject a non-conventional message" >&2
              exit 1
            fi

            echo 'fix: a valid conventional commit message' > good-msg
            set +e
            ${commitMsgHook} good-msg
            goodStatus=$?
            set -e
            echo "commit-msg hook exit status for good-msg: $goodStatus"
            if [ "$goodStatus" -ne 0 ]; then
              echo "expected commit-msg hook to accept a conventional message" >&2
              exit 1
            fi

            touch $out
          '';
    };
}
