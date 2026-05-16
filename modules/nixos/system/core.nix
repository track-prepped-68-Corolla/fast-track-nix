{ lib, pkgs, config, inputs, ... }:

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
    nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
    system.stateVersion                 = lib.mkDefault "24.11";
    environment.systemPackages = with pkgs; [ git neovim curl wget ];
  };
}
