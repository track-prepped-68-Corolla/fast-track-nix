let
  dir = builtins.readDir ./.;
  isModule = name: _: name != "default.nix" && builtins.match ".*\\.nix" name != null;
  filterAttrs = pred: attrs:
    builtins.listToAttrs (
      builtins.filter (kv: pred kv.name kv.value) (
        builtins.map (name: { inherit name; value = attrs.${name}; }) (builtins.attrNames attrs)
      )
    );
in
{
  imports = map (name: ./. + "/${name}") (builtins.attrNames (filterAttrs isModule dir));
}
