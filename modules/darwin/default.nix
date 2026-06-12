# =============================================================================
# Framework Darwin Module Hub
# =============================================================================
#
# Entry-point for framework Darwin modules. Injected into every
# darwinConfiguration generated for the consumer.
#
# Darwin module support is not yet implemented. Drop .nix files here when
# ready — lib.filesystem.listFilesRecursive auto-discovers them; no imports
# list to update. Each file must declare options.ft.*.enable via
# lib.mkEnableOption.
# =============================================================================
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.;
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
in
{
  imports = validModules;
}
