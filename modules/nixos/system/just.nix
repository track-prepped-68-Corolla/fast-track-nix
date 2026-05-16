{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ft.cli;

  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    exec ${pkgs.just}/bin/just \
      --justfile "${config.ft.repoPath}/scripts/ft.just" \
      --working-directory "${config.ft.repoPath}" \
      "$@"
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
