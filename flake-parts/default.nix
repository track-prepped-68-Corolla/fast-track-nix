# Auto-imports every sibling *.nix except itself.  Uses builtins directly
# because this file is evaluated before flake-parts is instantiated — no lib
# is in scope at this point.
let
  dir = builtins.readDir ./.;
  isModule = name: _: name != "default.nix" && builtins.match ".*\\.nix" name != null;
  filterAttrs =
    pred: attrs:
    builtins.listToAttrs (
      builtins.filter (kv: pred kv.name kv.value) (
        builtins.map (name: {
          inherit name;
          value = attrs.${name};
        }) (builtins.attrNames attrs)
      )
    );
in
{
  imports = map (name: ./. + "/${name}") (builtins.attrNames (filterAttrs isModule dir));
}
