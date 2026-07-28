{ config, lib, ... }:

################################################################################
# GUEST-SIDE HOST-SHARED SOPS SECRETS
#
# The guest half of the decoupled secrets flow: wires sops-nix inside a
# standalone microVM guest so it can decrypt secrets from the consumer's sops
# tree, which the host shares in read-only at /var/secrets (see the host half,
# ft.microvms.instances.<name>.shareSecrets). The guest decrypts on its OWN
# persistent ed25519 SSH host key — a stable age recipient across rebuilds — so
# no host key material is baked into the image.
#
# The encrypted keys themselves are declared by whatever consumes them (e.g.
# ft.komodo.secrets.{core,periphery}); this module only provides the plumbing:
# the age identity, the sshd that serves its public key for the one-time
# recipient bootstrap, and the mount of the shared secrets.
#
# Guest-only: it sets guest options (microvm.volumes/shares), which don't exist
# on a real host, so it lives in the modules/vm/ subtree and is injected into
# guests by flake-parts/vms.nix — NOT via the modules/nixos hub. Enable it in a
# vms/<name>; inert unless enabled.
################################################################################

let
  cfg = config.ft.vmSecrets;
  # The guest's persistent host key doubles as the sops age identity. It lives on
  # its own volume (below), not /etc/ssh, so it survives guest rebuilds.
  hostKey = "/var/lib/ssh/ssh_host_ed25519_key";
in
{
  options.ft.vmSecrets = {
    enable = lib.mkEnableOption "host-shared sops secrets for a microVM guest" // {
      description = "Wires sops-nix inside a microVM guest so it can decrypt secrets from the consumer's sops tree, which the host shares in read-only at /var/secrets. The guest gets a persistent ed25519 SSH host key on its own volume (its stable age recipient), sshd is enabled so that key can be read via ssh-keyscan for the one-time .sops.yaml bootstrap, and the shared secrets are mounted. Pair with ft.microvms.instances.<name>.shareSecrets on the host and a consumer of the keys such as ft.komodo.secrets.*. Enable it in a vms/<name>.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.str;
      default = "komodo.yaml";
      description = "Filename inside the shared /var/secrets directory holding this guest's sops-encrypted secrets (encrypted to the guest's age recipient). Becomes the guest's sops defaultSopsFile.";
    };

    sshKeyVolumeSize = lib.mkOption {
      type = lib.types.int;
      default = 16;
      description = "Size, in MiB, of the persistent volume that stores the guest's ed25519 SSH host key — the sops age identity. A host key is tiny, so the default is ample.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Persistent volume for the guest's ed25519 host key. Left unwrapped so it
    # merges (concatenates) with the guest's own microvm.volumes.
    microvm.volumes = [
      {
        image = "/var/lib/microvm/${config.networking.hostName}/sshkeys.img";
        mountPoint = "/var/lib/ssh";
        size = cfg.sshKeyVolumeSize;
      }
    ];

    # Read-only share of the host's sops tree (host path provisioned by
    # ft.microvms.instances.<name>.shareSecrets). mkDefault so it CONCATENATES
    # with the guest baseline's mkDefault auto host-share (equal priority = both
    # kept) rather than replacing it — a secrets VM still keeps /srv/host-share.
    # A vms/<name> that sets microvm.shares at normal priority overrides both.
    microvm.shares = lib.mkDefault [
      {
        source = "/var/lib/microvm/${config.networking.hostName}/secrets";
        mountPoint = "/var/secrets";
        tag = "vm-secrets";
        proto = "virtiofs";
      }
    ];

    # Persist the guest's ed25519 host key so it stays a stable age recipient.
    # sshd generates it on first boot and serves the public key to ssh-keyscan
    # for the one-time recipient bootstrap into var/secrets/.sops.yaml.
    services.openssh = {
      enable = lib.mkDefault true;
      # Unwrapped so a vms/<name> can add its own host keys and have them merge.
      hostKeys = [
        {
          path = hostKey;
          type = "ed25519";
        }
      ];
      settings = {
        PasswordAuthentication = lib.mkDefault false;
        KbdInteractiveAuthentication = lib.mkDefault false;
      };
    };

    # Guest sops-nix: decrypt <sopsFile> from the shared /var/secrets on the
    # guest's own host key. The keys are declared by their consumer (e.g.
    # ft.komodo.secrets.*), so none are listed here. sops-nix itself is already
    # imported by the framework's ft.sops module (hub-level, unconditional), so
    # the `sops` option exists here without an explicit import.
    sops = {
      defaultSopsFile = lib.mkDefault "/var/secrets/${cfg.sopsFile}";
      validateSopsFiles = lib.mkDefault false;
      age.sshKeyPaths = [ hostKey ];
      gnupg.sshKeyPaths = [ ];
    };
  };
}
