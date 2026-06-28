# =============================================================================
# Colmena hive — flake-parts module
# =============================================================================
#
# Emits flake.colmenaHive from the same machines the generator discovers, so a
# fleet can be built and activated remotely with `colmena apply`. This is pure
# wiring: it consumes the nixosConfigurations the generator already produces (via
# the shared module list) and the per-machine ft.deploy.* metadata, and maps the
# latter onto colmena's deployment.* options. No deploy logic lives in a module.
#
# A machine joins the hive only if it opted in with `ft.deploy.enable = true`,
# so machines that should only be deployed locally (laptops) or built as images
# never become remote-push targets. Image machines are excluded outright.
# =============================================================================
{ inputs, ... }:
let
  inherit (inputs) nixpkgs colmena;
  inherit (nixpkgs) lib;

  machinesLib = import ./lib/machines.nix { inherit inputs; };
  inherit (machinesLib) deployableMachines mkNixosModules;

  # Membership requires reading ft.deploy.enable, which means evaluating the
  # machine config. This is eval-time only (no build) and forces the same module
  # fixpoint colmena evaluates per node anyway.
  deployOf =
    machine:
    (lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = mkNixosModules machine;
    }).config.ft.deploy;

  enabledMachines = builtins.filter (m: (deployOf m).enable) deployableMachines;

  # Bridge the framework's generic ft.deploy.* metadata onto colmena's
  # deployment.* options. targetHost = null lets colmena fall back to the node
  # name (resolved via DNS / Tailscale MagicDNS).
  bridgeModule =
    { config, ... }:
    let
      d = config.ft.deploy;
    in
    {
      deployment = {
        inherit (d)
          targetHost
          targetUser
          tags
          buildOnTarget
          ;
      };
    };

  mkNode = machine: {
    imports = mkNixosModules machine ++ [ bridgeModule ];
  };

  nodes = lib.listToAttrs (map (m: lib.nameValuePair m.name (mkNode m)) enabledMachines);

  # Per-node nixpkgs so mixed-architecture fleets evaluate against the right
  # package set; meta.nixpkgs is the x86_64-linux default colmena requires.
  nodeNixpkgs = lib.listToAttrs (
    map (m: lib.nameValuePair m.name (import nixpkgs { inherit (m) system; })) enabledMachines
  );
in
{
  flake.colmenaHive = colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
        inherit nodeNixpkgs;
        specialArgs = { inherit inputs; };
      };
    }
    // nodes
  );
}
