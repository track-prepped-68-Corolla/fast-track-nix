# =============================================================================
# Framework NixOS Module Hub — Lazy Import Discovery
# =============================================================================
#
# Single entry-point for ALL framework NixOS modules.  For each .nix file
# found under this tree a wrapper module is generated that:
#   * declares options.ft.<name>.enable (sourced from the module's meta block)
#   * imports the module unconditionally (config is gated internally by mkIf)
#
# Modules that set options from external inputs (jovian, stylix, sops-nix,
# nix-index) declare their own `imports = [ inputs.<foo>.nixosModules.<bar> ]`.
# The mkWrapper partial evaluation uses `inputs = {}` but only accesses
# `meta.description`, so the imports thunk is never forced — safe under lazy eval.
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
  # NixOS treats unknown top-level module keys as config assignments.  Individual
  # modules set `meta.description = "..."` so the hub can read it during partial
  # evaluation; declaring the option here absorbs those assignments cleanly.
  # lib.types.lines accepts multiple string definitions (one per module) and
  # concatenates them — no conflict, and the runtime value is never queried.
  options.meta.description = lib.mkOption {
    type = lib.types.lines;
    default = "";
    internal = true;
    description = "Documentation sink — individual modules set this for the hub to read at partial-evaluation time; the runtime value is unused.";
  };

  imports = builtins.map mkWrapper validModules;
}
