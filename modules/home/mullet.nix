{
  config,
  lib,
  pkgs,
  ftUserPath ? null,
  ...
}:

################################################################################
# MULLET MODULE (Home Manager) — imperative package escape hatch
# ------------------------------------------------------------------------------
# Home Manager counterpart of the NixOS ft.mullet module. Same newline-
# delimited package-name file format, resolved into home.packages instead of
# environment.systemPackages. When generated via ft-home.lib.mkFlake,
# sourcePath defaults to var/mullet.txt inside this user's own
# users/<username>/ directory — no consumer configuration required.
################################################################################

let
  cfg = config.ft.mullet;

  # Safely read the file, providing an empty string if it doesn't exist yet.
  content =
    if cfg.sourcePath == null then
      ""
    else if builtins.pathExists cfg.sourcePath then
      builtins.readFile cfg.sourcePath
    else
      "";

  # Clean up the raw text into a list of strings.
  rawLines = lib.splitString "\n" content;
  pkgNames = builtins.filter (n: n != "") rawLines;

  # Resolver for nested attributes (e.g. "vimPlugins.LazyVim" -> ["vimPlugins" "LazyVim"]).
  resolvePkg =
    name:
    let
      pathList = lib.splitString "." name;
    in
    lib.attrsets.attrByPath pathList null pkgs;

  # Map the names to actual packages, filtering out nulls from typos/absent attrs.
  mulletPackages = builtins.filter (p: p != null) (builtins.map resolvePkg pkgNames);
in
{
  options.ft.mullet = {
    enable = lib.mkEnableOption "imperative package management (the Mullet)" // {
      description = "Lets you add or remove your own packages by editing a plain text file instead of touching Nix. Every package name listed in the file at `ft.mullet.sourcePath` gets installed for this user; names that don't resolve to a real package are just skipped. This is the Home Manager counterpart of the NixOS `ft.mullet` module.";
    };

    sourcePath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = if ftUserPath == null then null else ftUserPath + "/var/mullet.txt";
      example = lib.literalExpression "./var/mullet-custom.txt";
      description = "Path to the plain text file listing this user's package names, one per line. When this configuration comes from `ft-home.lib.mkFlake`, it defaults to `var/mullet.txt` inside this user's own `users/<username>/` directory. Set it yourself to use a different location, or if you're using this module outside the generator where no default is available.";
    };
  };

  config = lib.mkIf cfg.enable {
    # NOTE: deliberately NOT wrapped in lib.mkDefault. `home.packages` is a
    # list-type option: the module system filters definitions by override
    # priority *before* merging, so a mkDefault (priority 1000) list is
    # dropped wholesale whenever any other module contributes home.packages at
    # normal priority (100) — which stylix, git-workflow, karousel and others
    # all do. Wrapping this in mkDefault silently discards every mullet package.
    # Contribute at normal priority so the list concatenates. (The NixOS
    # counterpart already does this for environment.systemPackages.)
    home.packages = mulletPackages;
  };
}
