{
  lib,
  config,
  options,
  inputs,
  pkgs,
  ...
}:

let
  cfg = config.ft.sops;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.ft.sops = {
    enable = lib.mkEnableOption "sops-nix secret management" // {
      description = "Sets up encrypted secrets management, pointing sops-nix at `ft.repoPath/var/secrets/secrets.yaml` and decrypting with the machine's SSH host key. Turn on `ft.sops.useTPM` or `ft.sops.useYubikey` instead if you'd rather decrypt with a hardware token.";
    };
    useTPM = lib.mkEnableOption "TPM2 for decryption via age-plugin-tpm" // {
      description = "Adds `age-plugin-tpm`, turns on the TPM2 subsystem, and points sops at the age identity in `/var/lib/sops-nix/key.txt`, which the TPM plugin fills in.";
    };
    useYubikey = lib.mkEnableOption "Yubikey for decryption via age-plugin-yubikey" // {
      description = "Adds `age-plugin-yubikey`, starts the `pcscd` service for smart-card access, and points sops at the age identity stub in `/var/lib/sops-nix/key.txt`, which the YubiKey plugin fills in.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.ft.repoPath != options.ft.repoPath.default;
        message = "ft.sops.enable requires ft.repoPath to point at your consumer repo's real path — it is still the framework default (\"${options.ft.repoPath.default}\"), so sops.defaultSopsFile would resolve to a path that doesn't exist on this machine.";
      }
    ];

    environment.systemPackages = [
      pkgs.sops
      pkgs.age
    ]
    ++ lib.optional cfg.useTPM pkgs.age-plugin-tpm
    ++ lib.optional cfg.useYubikey pkgs.age-plugin-yubikey;

    services.pcscd.enable = lib.mkIf cfg.useYubikey (lib.mkDefault true);
    security.tpm2.enable = lib.mkIf cfg.useTPM (lib.mkDefault true);

    sops = {
      defaultSopsFile = "${config.ft.repoPath}/var/secrets/secrets.yaml";
      validateSopsFiles = false;
      age = {
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = lib.mkIf (cfg.useTPM || cfg.useYubikey) (lib.mkDefault "/var/lib/sops-nix/key.txt");
      };
      gnupg.sshKeyPaths = [ ];
    };
  };
}
