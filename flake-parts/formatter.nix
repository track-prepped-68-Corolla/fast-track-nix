_: {
  perSystem =
    { pkgs, ... }:
    {
      # nix fmt runs the formatter in a restricted environment with no PATH.
      # Wrap treefmt in a shell script that exports the paths of every tool it
      # delegates to (nixfmt, deadnix) so treefmt can exec them.
      formatter = pkgs.writeShellScriptBin "format" ''
        export PATH="${
          pkgs.lib.makeBinPath (
            with pkgs;
            [
              treefmt
              nixfmt
              deadnix
            ]
          )
        }:$PATH"
        exec "${pkgs.treefmt}/bin/treefmt" "$@"
      '';
    };
}
