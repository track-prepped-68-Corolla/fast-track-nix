{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.just;
  flakeDir = config.ft.repoPath;
  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    exec ${pkgs.just}/bin/just --justfile "${flakeDir}/scripts/ft.just" --working-directory "${flakeDir}" "$@"
  '';
in
{
  meta.description = "Installs just and a thin ft wrapper that invokes the repo's scripts/ft.just justfile from any working directory. Requires ft.repoPath to point to your consumer repo root.";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.just
      ftWrapper
    ];
  };
}
