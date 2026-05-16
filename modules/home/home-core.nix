{ config, lib, inputs, ... }:

{
  options.ft.repoPath = lib.mkOption {
    type        = lib.types.str;
    default     = "";
    description = "Absolute path to the flake repo on disk. Auto-read from var/local/repoPath; written by bootstrap.";
  };

  config = {
    ft.repoPath = lib.mkDefault (
      let f = inputs.self + "/var/local/repoPath";
      in if builtins.pathExists f then lib.removeSuffix "\n" (builtins.readFile f) else ""
    );
    programs.home-manager.enable = true;
    home.stateVersion            = lib.mkDefault "24.05";
    home.homeDirectory           = lib.mkDefault "/home/${config.home.username}";
    targets.genericLinux.enable  = lib.mkDefault true;
    xdg.enable                   = lib.mkDefault true;
  };
}
