# uv2nix wiring for the in-development ft_py CLI (scripts/ft_py). Builds the
# uv.lock-pinned workspace with pure Nix — no IFD. Framework-internal only:
# this file is auto-imported by flake-parts/default.nix (used when evaluating
# fast-track-nix's own flake), but deliberately NOT added to exports.nix's
# lib.mkFlake import list, so it never reaches consumer flakes. Keeps ft_py
# side-by-side with the existing just-based `ft` CLI until full parity across
# all seven just-files is reached.
{ inputs, ... }:
let
  inherit (inputs) pyproject-nix uv2nix pyproject-build-systems;
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ../scripts/ft_py; };
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
  editableOverlay = workspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; };
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      python = pkgs.python3;
      pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.wheel
          overlay
        ]
      );
      editablePythonSet = pythonSet.overrideScope editableOverlay;
    in
    {
      packages.ft-py = pythonSet.mkVirtualEnv "ft-py-env" workspace.deps.default;

      devShells.ft-py = pkgs.mkShell {
        packages = [
          (editablePythonSet.mkVirtualEnv "ft-py-dev-env" workspace.deps.all)
          pkgs.uv
        ];
        env = {
          UV_NO_SYNC = "1";
          UV_PYTHON = editablePythonSet.python.interpreter;
          UV_PYTHON_DOWNLOADS = "never";
        };
        shellHook = ''
          unset PYTHONPATH
          export REPO_ROOT="$(git rev-parse --show-toplevel)/scripts/ft_py"
        '';
      };
    };
}
