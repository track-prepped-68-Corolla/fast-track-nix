# =============================================================================
# Framework NixOS Module Hub — Lazy Import Discovery
# =============================================================================
#
# Single entry-point for ALL framework NixOS modules.  For each .nix file
# found under this tree a wrapper module is generated that:
#   * declares options.ft.<name>.enable
#   * imports the real module only when that flag is true
#
# meta.description (and optionally meta.default) inside each module are
# extracted via partial evaluation with stub arguments and surfaced in the
# generated enable option.
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
    { config, ... }:
    {
      options.ft.${name}.enable = lib.mkEnableOption name // {
        description = meta.description or "Whether to enable ${name}.";
      } // lib.optionalAttrs (meta ? default) { inherit (meta) default; };
      imports = lib.optionals config.ft.${name}.enable [ path ];
    };
in
{
  imports = builtins.map mkWrapper validModules;
}
