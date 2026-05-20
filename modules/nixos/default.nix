# =============================================================================
# Framework NixOS Module Hub
# =============================================================================
#
# Single entry-point for ALL framework NixOS modules. Passed as `ftNixos` to
# lib/generator.nix and injected into every nixosConfiguration and
# darwinConfiguration generated for the consumer.
#
# HOW IT WORKS
#   lib.filesystem.listFilesRecursive discovers every .nix file in this tree
#   at evaluation time and feeds them all to the NixOS module system. The
#   module system evaluates each file lazily — a module's config block only
#   runs when its ft.*.enable option is true, so importing everything here
#   costs nothing for disabled modules.
#
# HOW TO ADD A MODULE
#   Drop a .nix file anywhere under modules/nixos/. No imports list to update.
#   The file must declare an options.ft.*.enable using lib.mkEnableOption.
#   See any existing module for the template.
# =============================================================================
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.;

  # Exclude non-.nix files and this file itself to prevent an import cycle.
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
in
{
  imports = validModules;
}
