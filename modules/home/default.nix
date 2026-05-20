# =============================================================================
# Framework Home Manager Module Hub
# =============================================================================
#
# Single entry-point for ALL framework Home Manager modules. Passed as `ftHome`
# to lib/generator.nix and injected into every homeConfiguration generated for
# the consumer.
#
# HOW IT WORKS
#   lib.filesystem.listFilesRecursive discovers every .nix file in this tree
#   at evaluation time and feeds them to the Home Manager module system.
#   Config blocks are only evaluated when their ft.*.enable option is true.
#
# HOW TO ADD A MODULE
#   Drop a .nix file anywhere under modules/home/. No imports list to update.
#   The file must declare an options.ft.*.enable using lib.mkEnableOption.
# =============================================================================
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.
  ;

  # Exclude non-.nix files and this file itself to prevent an import cycle.
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
in
{
  imports = validModules;
}
