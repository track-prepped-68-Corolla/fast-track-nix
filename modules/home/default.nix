# =============================================================================
# Framework Home Manager Module Hub
# =============================================================================
#
# Single entry-point for ALL framework Home Manager modules. Passed as `ftHome`
# to lib/generator.nix and injected into every homeConfiguration generated for
# the consumer.
#
# HOW IT WORKS
#   mkWrapper lazily discovers every .nix file in this tree, partially evaluates
#   its meta attribute, then generates an inline wrapper that declares
#   options.ft.<name>.enable and conditionally imports the module only when
#   that option is true.
#
# HOW TO ADD A MODULE
#   Drop a .nix file anywhere under modules/home/. No imports list to update.
#   The file must declare a top-level meta.description string.
# =============================================================================
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./. ;
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
  mkWrapper = path:
    let
      baseName = baseNameOf path;
      name =
        if baseName == "default.nix" then baseNameOf (dirOf path)
        else lib.removeSuffix ".nix" baseName;
      raw = import path;
      moduleAttrs =
        if builtins.isFunction raw then
          raw { config = { }; pkgs = { }; options = { }; lib = lib; inputs = { }; }
        else raw;
      meta = moduleAttrs.meta or { };
    in
    { config, ... }:
    {
      options.ft.${name}.enable = lib.mkEnableOption name // {
        description = meta.description or "Whether to enable ${name}.";
      } // lib.optionalAttrs (meta ? default) { inherit (meta) default; };
      imports = lib.optionals config.ft.${name}.enable [ path ];
    };
in
{ imports = builtins.map mkWrapper validModules; }
