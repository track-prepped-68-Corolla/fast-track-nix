{ config, lib, inputs, ... }:

{
  options.ft = {
    primaryHost = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = "Hostname of the machine this home config primarily runs on. Set once in homes/<user>/default.nix. Used by host-facts.nix to read hosts/<hostname>/var/facter.json.";
    };

    repoPath = lib.mkOption {
      type        = lib.types.str;
      default     = "";
      description = "Absolute path to the flake repo on disk. Set once in homes/<user>/default.nix; written to var/local by bootstrap.";
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
