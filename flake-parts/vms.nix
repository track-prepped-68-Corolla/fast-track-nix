# =============================================================================
# microVM generator — flake-parts module
# =============================================================================
#
# Discovers the consumer's vms/<name>/ directories (the VM analogue of
# machines/) and emits each as a STANDALONE nixosConfigurations.<name>, built
# with the microvm *guest* module, plus a packages.<system>.microvm-<name>
# runner. A host runs one by reference — ft.microvms sets
# microvm.vms.<name>.flake = self — so the guest closure is never evaluated
# inside the host (the Phase 2 decoupling; see modules/vm/vm-guest-base.nix).
#
# A VM is thin, exactly like a machine: vms/<name>/default.nix sets ft.* (a
# docker VM enables ft.containers + ft.komodo), resources, and its tap
# interface. Everything else comes from the injected hub + guest baseline.
# =============================================================================
{ inputs, ... }:
let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  getDirs =
    path:
    if builtins.pathExists path then
      lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else
      [ ];

  vmsDir = self + "/vms";
  vmNames = getDirs vmsDir;

  # Per-VM system: vms/<name>/var/system if present, else x86_64-linux (microVMs
  # are almost always x86_64-linux).
  systemOf =
    name:
    let
      f = vmsDir + "/${name}/var/system";
    in
    if builtins.pathExists f then lib.removeSuffix "\n" (builtins.readFile f) else "x86_64-linux";

  # Generic microVM guest baseline (hypervisor, DHCP, stateVersion). It is a
  # NixOS module, so it lives under modules/ — in its own modules/vm/ subtree,
  # not the nixos/ hub, so listFilesRecursive never applies it to a real host.
  # Imported explicitly here (guests only).
  guestBase = import ../modules/vm/vm-guest-base.nix;

  # Host-only / guest-incompatible modules pulled out of the hub for guests,
  # mirroring lib.vmTestBase. The two microvm modules reference the host-only
  # `microvm.vms` option, which a guest (guest module only) does not declare;
  # disko-btrfs / gaming / facter-system are guest-inappropriate or heavy, same
  # as in the VM test base.
  guestDisabledModules = [
    "${self}/modules/nixos/services/microvm.nix"
    "${self}/modules/nixos/services/microvm-docker.nix"
    "${self}/modules/nixos/hardware/disko-btrfs.nix"
    "${self}/modules/nixos/profiles/gaming.nix"
    "${inputs.nixos-facter-modules}/modules/nixos/system.nix"
  ];

  mkVm =
    name:
    let
      system = systemOf name;
    in
    lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        inputs.microvm.nixosModules.microvm
        (import ../modules/nixos)
        { disabledModules = guestDisabledModules; }
        guestBase
        (vmsDir + "/${name}")
        {
          networking.hostName = lib.mkDefault name;
          nixpkgs.hostPlatform = lib.mkDefault system;
        }
      ];
    };

  vmConfigs = builtins.listToAttrs (map (name: lib.nameValuePair name (mkVm name)) vmNames);

  # Runner packages keyed by each VM's system (build/boot the guest directly).
  runnerPackages = lib.foldl' (
    acc: name:
    lib.recursiveUpdate acc {
      ${systemOf name}."microvm-${name}" = vmConfigs.${name}.config.microvm.declaredRunner;
    }
  ) { } vmNames;
in
{
  # Merges with the machine generator's nixosConfigurations / packages. VM names
  # must not collide with machine names.
  flake.nixosConfigurations = vmConfigs;
  flake.packages = runnerPackages;
}
