{
  config,
  lib,
  options,
  pkgs,
  ...
}:

################################################################################
# CLI MODULE (Home Manager) — the `ft` command
# ------------------------------------------------------------------------------
# Installs just and a thin `ft` wrapper into the user profile. Independent of
# the NixOS ft.cli module — useful on standalone Home Manager systems and
# non-NixOS distros (e.g. SteamOS, Bazzite) where there is no system-level
# ft.cli to rely on.
################################################################################

let
  cfg = config.ft.cli;
  flakeDir = config.ft.repoPath;
  scriptsDir = ../../scripts;
  ftWrapper = pkgs.writeShellScriptBin "ft" ''
    export FT_REPO="${flakeDir}"
    exec ${pkgs.just}/bin/just --justfile "${scriptsDir}/ft.just" --working-directory "${flakeDir}" "$@"
  '';
in
{
  options.ft.cli = {
    enable = lib.mkEnableOption "Fast Track CLI (ft command)" // {
      description = "Installs just and a thin `ft` wrapper that invokes the repo's `scripts/ft.just` justfile from any working directory. Home Manager counterpart of the NixOS ft.cli module, independently useful on standalone Home Manager systems or non-NixOS distros (SteamOS, Bazzite). Requires `ft.repoPath` to point to your consumer repo root.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.repoPath != options.ft.repoPath.default;
        message = "ft.cli.enable requires ft.repoPath to point at your consumer repo's real path — it is still the framework default (\"${options.ft.repoPath.default}\"), so the ft wrapper would run recipes against a path that doesn't exist on this machine.";
      }
    ];

    home.packages = lib.mkDefault [
      pkgs.just
      ftWrapper
    ];
  };
}
