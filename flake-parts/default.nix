let
  dir = builtins.readDir ./.;
  isModule = name: _: name != "default.nix" && builtins.match ".*\\.nix" name != null;
in
{
  imports = map (name: ./. + "/${name}") (builtins.attrNames (builtins.filterAttrs isModule dir));
}
