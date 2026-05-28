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

  meta.description = "Configures user-level sops-nix secrets: sets the age keyfile and default secrets file path derived from ft.repoPath and the current username.";

  config = lib.mkIf cfg.enable {
    sops = {
      age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      defaultSopsFile = lib.mkDefault "${config.ft.repoPath}/users/${config.home.username}/var/secrets.yaml";
    };
  };
}
