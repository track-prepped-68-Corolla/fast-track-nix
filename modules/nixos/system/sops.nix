{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.ft.sops = {
    enable = lib.mkEnableOption "sops-nix secret management" // {
      description = "Wires up sops-nix pointing at `ft.repoPath/secrets/secrets.yaml`, using the machine's SSH host key for age decryption. Enable `ft.sops.useTPM` or `ft.sops.useYubikey` for hardware-token decryption instead.";
    };
    useTPM = lib.mkEnableOption "TPM2 for decryption via age-plugin-tpm" // {
      description = "Adds age-plugin-tpm, enables the TPM2 subsystem, and configures sops to read the age identity from /var/lib/sops-nix/key.txt (populated by the TPM plugin).";
    };
    useYubikey = lib.mkEnableOption "Yubikey for decryption via age-plugin-yubikey" // {
      description = "Adds age-plugin-yubikey, starts pcscd for smart-card access, and configures sops to read the age identity stub from /var/lib/sops-nix/key.txt (populated by the YubiKey plugin).";
    };
  };

  config = lib.mkIf config.ft.sops.enable {
    environment.systemPackages = [
      pkgs.sops
      pkgs.age
    ]
    ++ lib.optional config.ft.sops.useTPM pkgs.age-plugin-tpm
    ++ lib.optional config.ft.sops.useYubikey pkgs.age-plugin-yubikey;

    services.pcscd.enable = lib.mkIf config.ft.sops.useYubikey true;
    security.tpm2.enable = lib.mkIf config.ft.sops.useTPM true;

    sops = {
      defaultSopsFile = "${config.ft.repoPath}/secrets/secrets.yaml";
      validateSopsFiles = false;
      age = {
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = lib.mkIf (
          config.ft.sops.useTPM || config.ft.sops.useYubikey
        ) "/var/lib/sops-nix/key.txt";
      };
      gnupg.sshKeyPaths = [ ];
    };
  };
}
