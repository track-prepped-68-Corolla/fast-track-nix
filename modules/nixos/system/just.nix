{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.cli;

  repoPath = config.ft.repoPath;

  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    exec ${pkgs.just}/bin/just --justfile "${repoPath}/scripts/ft.just" --working-directory "${repoPath}" "$@"
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
