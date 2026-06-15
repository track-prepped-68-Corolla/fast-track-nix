{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.cli;
  flakeDir = config.ft.repoPath;
  scriptsDir = ../../../scripts;
  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    export FT_REPO="${flakeDir}"
    exec ${pkgs.just}/bin/just --justfile "${scriptsDir}/ft.just" --working-directory "${flakeDir}" "$@"
  '';
in
{
  options.ft.cli = {
    enable = lib.mkEnableOption "Fast Track CLI (ft command)" // {
      description = "Installs just and a thin `ft` wrapper that invokes the repo's `scripts/ft.just` justfile from any working directory. Requires `ft.repoPath` to point to your consumer repo root.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.just
      ftWrapper
    ];
  };
}
