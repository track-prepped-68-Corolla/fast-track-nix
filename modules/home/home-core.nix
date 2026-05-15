{ config, lib, inputs, ... }:

{
  options.ft = {
    primaryHost = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = "Hostname of the machine this home config primarily runs on. Set once in homes/<user>/default.nix. Used to auto-read var/<hostname>/repo-path and var/<hostname>/facts.nix.";
    };

    repoPath = lib.mkOption {
      type    = lib.types.str;
      default = lib.removeSuffix "\n" (
        let
          h = config.ft.primaryHost;
          f = inputs.self + "/var/${h}/repo-path";
        in if h != "" && builtins.pathExists f then builtins.readFile f else ""
      );
      description = "Absolute path to the flake repo on disk. Auto-detected from var/<primaryHost>/repo-path.";
    };
  };

  config = {
    programs.home-manager.enable = true;
    home.stateVersion = lib.mkDefault "24.05";
    home.homeDirectory = lib.mkDefault "/home/${config.home.username}";
    targets.genericLinux.enable = lib.mkDefault true;
    xdg.enable = lib.mkDefault true;
  };
}
