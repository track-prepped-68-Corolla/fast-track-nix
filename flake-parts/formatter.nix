_: {
  perSystem =
    { pkgs, ... }:
    {
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
