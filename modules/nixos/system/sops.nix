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
      description = "Wires up sops-nix pointing at `ft.repoPath/var/secrets/secrets.yaml`, using the machine's SSH host key for age decryption. Enable `ft.security.sops.useTPM` or `ft.security.sops.useYubikey` for hardware-token decryption instead.";
    };
    useTPM = lib.mkEnableOption "TPM2 for decryption via age-plugin-tpm" // {
      description = "Adds age-plugin-tpm, enables the TPM2 subsystem, and configures sops to read the age identity from /var/lib/sops-nix/key.txt (populated by the TPM plugin).";
    };
    useYubikey = lib.mkEnableOption "Yubikey for decryption via age-plugin-yubikey" // {
      description = "Adds age-plugin-yubikey, starts pcscd for smart-card access, and configures sops to read the age identity stub from /var/lib/sops-nix/key.txt (populated by the YubiKey plugin).";
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
