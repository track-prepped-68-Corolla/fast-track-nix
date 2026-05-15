{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.cli;

  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    repo_path="$(cat /var/ft/repo-path 2>/dev/null)"
    if [ -z "$repo_path" ]; then
      echo "ft: repo path not set. Ensure ft.repoPath is configured and NixOS has been activated." >&2
      exit 1
    fi
    exec ${pkgs.just}/bin/just --justfile "$repo_path/scripts/ft.just" --working-directory "$repo_path" "$@"
  '';

in
{
  options.ft.cli = {
    enable = lib.mkEnableOption "Fast Track CLI (ft command)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.just
      ftWrapper
    ];
  };
}
