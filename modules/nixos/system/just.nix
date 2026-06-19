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
    # With no args, just's own `default` recipe would shell out to a bare
    # `just --list`, losing --justfile/--working-directory and searching the
    # caller's cwd instead. Pass --list directly so it never recurses through
    # the recipe.
    if [ "$#" -eq 0 ]; then
      exec ${pkgs.just}/bin/just --shell "${pkgs.bash}/bin/bash" --justfile "${scriptsDir}/ft.just" --working-directory "${flakeDir}" --list
    fi
    exec ${pkgs.just}/bin/just --shell "${pkgs.bash}/bin/bash" --justfile "${scriptsDir}/ft.just" --working-directory "${flakeDir}" "$@"
  '';
in
{
  options.ft.cli = {
    enable = lib.mkEnableOption "Fast Track CLI (ft command)" // {
      description = "Installs just and a thin `ft` wrapper that invokes the repo's `scripts/ft.just` justfile from any working directory. Requires `ft.repoPath` to point to your consumer repo root.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The bundled justfiles shell out to these at runtime: ssh-to-age and sops
    # for bootstrap secrets-init / tailscale-init / git-init, and jq for the
    # bulk-drive (drives.just) recipes. They are not guaranteed on PATH from
    # anywhere else (sops is only pulled in when ft.sops is enabled), so ship
    # them with the CLI itself rather than letting recipes fail mid-run.
    environment.systemPackages = [
      pkgs.just
      pkgs.ssh-to-age
      pkgs.sops
      pkgs.jq
      ftWrapper
    ];
  };
}
