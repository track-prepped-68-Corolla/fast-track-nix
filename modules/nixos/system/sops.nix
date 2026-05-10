{ lib, config, inputs, pkgs, ... }:

{
  # Import the NixOS module from the flake input
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.ft.security.sops = {
    enable = lib.mkEnableOption "sops-nix secret management";
    useTPM = lib.mkEnableOption "TPM2 for decryption via age-plugin-tpm";
    useYubikey = lib.mkEnableOption "Yubikey for decryption via age-plugin-yubikey";
  };

  config = lib.mkIf config.ft.security.sops.enable {
    environment.systemPackages = [
      pkgs.sops
      pkgs.age
    ] ++ lib.optional config.ft.security.sops.useTPM pkgs.age-plugin-tpm
      ++ lib.optional config.ft.security.sops.useYubikey pkgs.age-plugin-yubikey;

    services.pcscd.enable = lib.mkIf config.ft.security.sops.useYubikey true;
    security.tpm2.enable = lib.mkIf config.ft.security.sops.useTPM true;

    sops = {
      # Leverages ft.flakeDir defined in core.nix
      defaultSopsFile = "${config.ft.flakeDir}/secrets/secrets.yaml";
      validateSopsFiles = false;

      # Automatically use the machine's SSH key for decryption
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      # For hardware tokens — identity file contains the stubs (public references)
      age.keyFile = lib.mkIf (config.ft.security.sops.useTPM || config.ft.security.sops.useYubikey) "/var/lib/sops-nix/key.txt";

      gnupg.sshKeyPaths = [ ];
    };
  };
}
