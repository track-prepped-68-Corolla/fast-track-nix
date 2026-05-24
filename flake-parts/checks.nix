{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      statixConfig = inputs.self + "/statix.toml";
      configArg = pkgs.lib.optionalString (builtins.pathExists statixConfig) "--config ${statixConfig}";
    in
    {
      checks = {
        format = pkgs.runCommand "format-check" {
          nativeBuildInputs = with pkgs; [
            nixfmt
            deadnix
            findutils
            diffutils
          ];
        } ''
          cp -r ${inputs.self}/. ref
          cp -r ${inputs.self}/. src
          find src \( -type f -o -type d \) -exec chmod u+w {} +
          find src -type f -name "*.nix" | sort | xargs -r nixfmt
          find src -type f -name "*.nix" | sort | xargs -r deadnix --edit
          find src -type f -name "*.nix" | sort | xargs -r deadnix --edit
          if ! diff -r -q src ref; then
            echo "Some Nix files need formatting."
            echo "Run: nixfmt <file> && deadnix --edit <file>"
            exit 1
          fi
          touch $out
        '';

        lint = pkgs.runCommand "statix-check" {
          nativeBuildInputs = [ pkgs.statix ];
        } ''
          cp -r ${inputs.self}/. .
          statix check . ${configArg}
          touch $out
        '';
      };
    };
}
