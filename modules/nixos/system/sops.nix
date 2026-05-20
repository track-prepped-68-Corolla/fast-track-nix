{ lib, config, inputs, pkgs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.ft.security.sops = {
    enable = lib.mkEnableOption "sops-nix secret management" // {
      description = "Wires up sops-nix pointing at `ft.repoPath/secrets/secrets.yaml`, using the machine's SSH host key for age decryption. Enable `ft.security.sops.useTPM` or `ft.security.sops.useYubikey` for hardware-token decryption instead.";
    };
    useTPM = lib.mkEnableOption "TPM2 for decryption via age-plugin-tpm" // {
      description = "Adds age-plugin-tpm, enables the TPM2 subsystem, and configures sops to read the age identity from /var/lib/sops-nix/key.txt (populated by the TPM plugin).";
    };
    useYubikey = lib.mkEnableOption "Yubikey for decryption via age-plugin-yubikey" // {
      description = "Adds age-plugin-yubikey, starts pcscd for smart-card access, and configures sops to read the age identity stub from /var/lib/sops-nix/key.txt (populated by the YubiKey plugin).";
    };
  };

  config = lib.mkIf config.ft.security.sops.enable {
    environment.systemPackages =
      [
        pkgs.sops
        pkgs.age
      ]
      ++ lib.optional config.ft.security.sops.useTPM pkgs.age-plugin-tpm
      ++ lib.optional config.ft.security.sops.useYubikey pkgs.age-plugin-yubikey;

    services.pcscd.enable = lib.mkIf config.ft.security.sops.useYubikey true;
    security.tpm2.enable = lib.mkIf config.ft.security.sops.useTPM true;

    sops = {
      defaultSopsFile = "${config.ft.repoPath}/secrets/secrets.yaml";
      validateSopsFiles = false;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      age.keyFile = lib.mkIf
        (config.ft.security.sops.useTPM || config.ft.security.sops.useYubikey)
        "/var/lib/sops-nix/key.txt";
      gnupg.sshKeyPaths = [ ];
    };
  };
}
