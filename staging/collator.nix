{ lib, ... }:

let
  root = ./.;

  # --- 1. The Strict Validator ---
  # Ensures a file is actually a module before importing it.
  # Uses regex to ignore leading whitespace or comments before the opening brace.
  isValidModule =
    path:
    let
      content = builtins.readFile path;
      isModule = builtins.match "[[:space:]|\n|#]*\\{.*" content != null;
    in
    isModule;

  # --- 2. The Optimized Directory Walker ---
  findAllNixFiles =
    dir:
    let
      contents = builtins.readDir dir;
    in
    lib.flatten (
      lib.mapAttrsToList (
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory" then
          # CRITICAL: Prune hidden directories (like .git) immediately to prevent slow evaluations
          if !(lib.hasPrefix "." name) then findAllNixFiles path else [ ]
        else if
          type == "regular"
          && lib.hasSuffix ".nix" name
          && name != "collator.nix"
          && !(lib.hasPrefix "." name)
        then # Ignore .swp or temporary files

          # Apply the syntax check
          if isValidModule path then [ path ] else [ ]
        else
          [ ]
      ) contents
    );

in
{
  # Only imports what is structurally sound and safely tracked
  imports = findAllNixFiles root;

  /*
    --- COLLATOR MAP ---
    This section is managed by the 'ft' maintenance CLI.
    It provides a visual list of every module currently being imported.
    -----------------------
  */
}
