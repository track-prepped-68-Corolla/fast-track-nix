{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.ft.sops;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  options.ft.sops = {
    enable = lib.mkEnableOption "user-level sops-nix secrets";
  };

  config = lib.mkIf cfg.enable {
    sops = {
      age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      defaultSopsFile = lib.mkDefault "${config.ft.repoPath}/users/${config.home.username}/var/secrets.yaml";
    };
  };
}
