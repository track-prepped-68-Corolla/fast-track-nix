{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.system.justWrapper;

  # Pull the directory from the global option we created in default.nix
  flakeDir = config.ft.flakeDir;

  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    exec ${pkgs.just}/bin/just --justfile "${flakeDir}/justfile" --working-directory "${flakeDir}" "$@"
  '';

in
{
  options.ft.system.justWrapper = {
    enable = lib.mkEnableOption "Fast Track Just wrapper (ft command)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.just
      ftWrapper
    ];
  };
}
