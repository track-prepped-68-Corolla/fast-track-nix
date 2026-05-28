# =============================================================================
# Framework NixOS Module Hub — Lazy Import Discovery
# =============================================================================
#
# Single entry-point for ALL framework NixOS modules.  For each .nix file
# found under this tree a wrapper module is generated that:
#   * declares options.ft.<name>.enable (sourced from the module's meta block)
#   * imports the module unconditionally (config is gated internally by mkIf)
#
# Heavy input modules (jovian, stylix, sops-nix, nix-index) are NO LONGER
# imported by the individual feature modules.  Hosts that need them must import
# the relevant nixosModule from inputs directly in their machine default.nix.
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
  imports = builtins.map mkWrapper validModules;
}
