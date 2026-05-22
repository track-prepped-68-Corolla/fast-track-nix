let
  dir = builtins.readDir ./.;
  isModule = name: _: builtins.match "[^_].*\\.nix" name != null && name != "default.nix";
in
{ imports = map (name: ./. + "/${name}") (builtins.attrNames (builtins.filterAttrs isModule dir)); }
