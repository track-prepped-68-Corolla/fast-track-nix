{
  config,
  lib,
  options,
  inputs,
  ...
}:

let
  cfg = config.ft.sops;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  options.ft.sops = {
    enable = lib.mkEnableOption "user-level sops-nix secrets" // {
      description = "Configures sops-nix for this user, pointing the age key at ~/.config/sops/age/keys.txt and the secrets file at the user's var/secrets.yaml in the consumer repo.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.repoPath != options.ft.repoPath.default;
        message = "ft.sops.enable requires ft.repoPath to point at your consumer repo's real path — it is still the framework default (\"${options.ft.repoPath.default}\"), so sops.defaultSopsFile would resolve to a path that doesn't exist on this machine.";
      }
    ];

    sops = {
      age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      defaultSopsFile = lib.mkDefault "${config.ft.repoPath}/users/${config.home.username}/var/secrets.yaml";
    };
  };
}
