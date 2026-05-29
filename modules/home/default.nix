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
    path:
      lib.hasSuffix ".nix" (builtins.toString path)
      && path != ./default.nix
  ) allFiles;

  mkWrapper =
    path:
    let
      baseName = baseNameOf path;
      name =
        if baseName == "default.nix" then
          baseNameOf (dirOf path)
        else
          lib.removeSuffix ".nix" baseName;

      raw = import path;
      moduleAttrs =
        if builtins.isFunction raw then
          raw {
            config = { };
            pkgs = { };
            options = { };
            inherit lib;
            inputs = { };
          }
        else
          raw;
      meta = moduleAttrs.meta or { };
    in
    {
      options.ft.${name}.enable = lib.mkEnableOption name // {
        description = meta.description or "Whether to enable ${name}.";
      };
      imports = [ path ];
    };
in
{
  # Same pattern as the NixOS hub: absorb meta.description assignments from
  # individual HM modules so the module system does not reject them.
  options.meta.description = lib.mkOption {
    type = lib.types.lines;
    default = "";
    internal = true;
    description = "Documentation sink — individual modules set this for the hub to read at partial-evaluation time; the runtime value is unused.";
  };

  imports = builtins.map mkWrapper validModules;
}
