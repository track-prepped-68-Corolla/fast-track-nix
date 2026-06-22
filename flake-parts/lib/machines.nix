# =============================================================================
# Shared machine discovery — plain helper (NOT a flake-parts module)
# =============================================================================
#
# Lives under flake-parts/lib/ so flake-parts/default.nix (which only scans its
# own top-level directory) does not auto-import it as a flake module. Imported
# explicitly by generator.nix and colmena.nix so the two cannot drift on how a
# machine is discovered or which modules a deployable NixOS machine gets.
#
# Usage:
#   machinesLib = import ./lib/machines.nix { inherit inputs; };
#   inherit (machinesLib) deployableMachines mkNixosModules;
# =============================================================================
{ inputs }:
let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  getDirs =
    path:
    if builtins.pathExists path then
      lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir path))
    else
      [ ];

  machinesDir = self + "/machines";
  machineNames = getDirs machinesDir;

  mkMachineEntry =
    name:
    let
      factsFile = self + "/machines/${name}/var/facter.json";
      facter =
        if builtins.pathExists factsFile then builtins.fromJSON (builtins.readFile factsFile) else { };
      system = facter.system or "x86_64-linux";
      isDarwin = lib.hasSuffix "-darwin" system;
    in
    {
      inherit name system isDarwin;
      path = machinesDir + "/${name}";
    };

  machineList = map mkMachineEntry machineNames;
  nixosMachines = builtins.filter (x: !x.isDarwin) machineList;
  darwinMachines = builtins.filter (x: x.isDarwin) machineList;

  # machines/<name>/var/format — presence marks an ISO image build rather than a
  # deployable system. Image machines are excluded from nixosConfigurations (and
  # from the colmena hive) so they don't fail filesystem/bootloader assertions.
  isImageMachine = machine: builtins.pathExists (machine.path + "/var/format");
  imageMachines = builtins.filter isImageMachine nixosMachines;
  deployableMachines = builtins.filter (m: !isImageMachine m) nixosMachines;

  # machines/<name>/var/kexec — presence opts the machine into a per-machine
  # kexec installer image (packages.<system>.<name>-kexec, see flake-parts/kexec.nix).
  # Gated by a marker file (like var/format) so flake-check stays lean for
  # machines that don't use the kexec self-install path.
  kexecMachines = builtins.filter (m: builtins.pathExists (m.path + "/var/kexec")) deployableMachines;

  # The standard module list for a deployable NixOS machine — shared by the
  # generator's nixosConfigurations and the colmena hive nodes.
  #
  # Disko and microvm host module are captured in the closure here (not via
  # module args) so they are available before any module imports are resolved.
  # Accessing inputs inside `imports` causes infinite recursion when inputs is
  # provided via _module.args rather than specialArgs (e.g. in NixOS VM smoke
  # tests).
  mkNixosModules = machine: [
    inputs.Disko.nixosModules.disko
    inputs.microvm.nixosModules.host
    ../../modules/nixos
    machine.path
    { nixpkgs.hostPlatform = lib.mkDefault machine.system; }
  ];
in
{
  inherit
    getDirs
    machineList
    nixosMachines
    darwinMachines
    imageMachines
    deployableMachines
    kexecMachines
    mkNixosModules
    ;
}
