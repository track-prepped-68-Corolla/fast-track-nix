_: {
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          treefmt
          nixfmt
          deadnix
          statix
          conform
          convco
          lefthook
          # Shell test suite (tests/shell/run.sh) tooling.
          bats
          shellcheck
          just
          jq
        ];
      };
    };
}
