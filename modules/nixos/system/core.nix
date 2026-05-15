{ lib, pkgs, config, inputs, ... }:

{
  options.ft = {
    repoPath = lib.mkOption {
      type    = lib.types.str;
      default = lib.removeSuffix "\n" (
        let
          h = config.networking.hostName;
          f = inputs.self + "/var/${h}/repo-path";
        in if builtins.pathExists f then builtins.readFile f else ""
      );
      description = ''
        Absolute path to the flake repo on disk.
        Auto-detected from var/<hostname>/repo-path when that file exists.
        Set by the bootstrap script; override manually only if needed.
      '';
    };
  };

  config = {
    nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
    system.stateVersion = lib.mkDefault "24.11";
    environment.systemPackages = with pkgs; [
      git
      neovim
      curl
      wget
    ];
  };
}