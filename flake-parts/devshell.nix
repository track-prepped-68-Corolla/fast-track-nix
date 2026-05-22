_:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          treefmt
          nixfmt
          deadnix
          statix
        ];
      };
    };
}
