# ft-home — Developer Reference

## Repository naming

The framework lives in the **`fast-track-nix`** GitHub repo. It is aliased as `ft-home` in flake inputs (reflecting the project's original name). The companion **`ft-home`** GitHub repo is a personal consumer of this framework — not the framework itself. Do not confuse the two.

---

## What this is

ft-home is a framework flake. Consumers add it as an input and call `ft-home.lib.mkFlake inputs` from a minimal `flake.nix`. `flake-parts/generator.nix` auto-discovers the consumer's `machines/` and `users/` directories and emits `nixosConfigurations`, `darwinConfigurations`, and `homeConfigurations`. All framework modules are injected automatically; users enable features via `ft.*` options.

Darwin support is declared in the generator but not yet implemented in the module tree.

---

## Architecture boundaries

### flake.nix is pure wiring

`flake.nix` exposes the following top-level outputs. No evaluation logic, no config generation, no module code lives in `flake.nix`.

| Export | Description |
|---|---|
| `lib.mkFlake` | Consumer entry point — delegates to the flake-parts generator |
| `lib.mergeInputs` | Canonical merge function: `frameworkInputs // consumerInputs` |
| `lib.mkVmTest` | Wraps `runNixOSTest` with the merged input set in `node.specialArgs` |
| `lib.vmTestBase` | Base NixOS module for VM test nodes — same hub as real machines + sandbox-compatible disabled modules |
| `nixosModules.default` | Framework NixOS module hub (disko + microvm + all `modules/nixos/`) |
| `homeManagerModules.default` | Framework Home Manager module hub (`modules/home/`) |

- Complex logic → `flake-parts/`
- NixOS/HM configuration → `modules/`
- flake-parts is used only to create flake modules. Never mix flake wiring into module code or module code into flake wiring (the dendritic pattern).

### No personal data, ever

ft-home must contain zero user-specific, machine-specific, or site-specific information. Usernames, hostnames, hardware IDs, IP addresses, real file paths, or any identifier unique to one person's setup must be stripped immediately when found. Every feature must be usable by any consumer without modification.

---

## Machine and user discovery

The generator (`flake-parts/generator.nix`) uses a flat directory structure:

- `machines/<name>/` — one directory per machine. System is read from `machines/<name>/var/facter.json` (`facter.system`). Falls back to `x86_64-linux` if absent. Names whose system ends in `-darwin` produce `darwinConfigurations`; all others produce `nixosConfigurations`.
- `users/<username>/` — one directory per user. Cross-producted with every system found in `machines/`, plus the local system from `var/local/system` (written by bootstrap).
- `users/<username>/profiles/<name>/` — optional extra Home Manager modules layered on top of a user's base config. Every non-empty combination of a user's profiles is generated as its own `homeConfigurations` entry, named `<user>+<profile1>+<profile2>...@<system>` with profile names in alphabetical order (e.g. `joe+gaming@x86_64-linux`, `joe+gaming+work@x86_64-linux`). The base `<user>@<system>` entry is unaffected.

Consumers never need to declare the system manually; facter.json is the source of truth.

fast-track-nix itself has no `machines/` entries — the generator produces empty outputs against the framework repo. The real exercise of the generator is `ft-home`'s CI, which runs against `machines/strix`.

---

## Module anatomy

Every module follows this template exactly:

```nix
{ pkgs, lib, config, ... }:
let
  cfg = config.ft.<feature>;
in
{
  options.ft.<feature> = {
    enable = lib.mkEnableOption "<short label>" // {
      description = "<one sentence describing what enabling this does>";
    };
    # additional mkOption declarations — always include `type` and `description`
  };

  config = lib.mkIf cfg.enable {
    # scalar values wrapped in lib.mkDefault (unless a security invariant);
    # list/attrset options left unwrapped so they merge — see the rules below
  };
}
```

### Rules that apply to every module

- Bind `cfg = config.ft.<feature>;` at the top with `let-in`. Never repeat the full attribute path inside the `config` block.
- Prefer `inherit (cfg) foo bar;` over `foo = cfg.foo; bar = cfg.bar;` repetition.
- Wrap **scalar** `config` values in `lib.mkDefault` so consumers can override without `lib.mkForce`.
- **Do not wrap list or attrset options in `lib.mkDefault`.** `mkDefault` lowers a definition's merge priority, and for a `listOf` / `attrsOf` option that causes a consumer defining entries at normal priority to *replace* the module's base wholesale instead of the two being merged (lists concatenated, attrsets combined). Leave lists and attrsets unwrapped so their definitions merge — wrap the individual scalar leaves inside them instead if they need defaulting. (A genuinely replaceable default list is a deliberate exception: use `mkDefault` there and comment why.)
- `lib.mkForce` is reserved exclusively for security or safety invariants that must not be overridden. Comment the reason when used.
- `lib.optional` / `lib.optionals` / `lib.optionalAttrs` instead of `if … then … else []`.
- `with pkgs;` is acceptable only inside list literals (e.g., `environment.systemPackages = with pkgs; [ … ]`). Never open `with pkgs;` at module scope.
- No `imports` inside individual feature modules unless pulling in an upstream input module (e.g., `inputs.sops-nix.nixosModules.sops`). Internal cross-module dependencies are handled by the module system, not by explicit imports.
- Every `lib.mkOption` call must include both `type` and `description` — this applies equally to top-level options and to sub-options declared as inline attributes under an option namespace (e.g. `ft.theme.fonts.sans.name`). Missing descriptions cause `nix flake check` to fail via the `option-docs-*` checks.

### Adding a module

Drop a `.nix` file anywhere under `modules/nixos/` or `modules/home/`. The `default.nix` hub in each uses `lib.filesystem.listFilesRecursive` — no imports list to update. The file is discovered and evaluated automatically on the next build.

**Workflow for new modules:**
1. Determine placement: does the feature require system privileges, daemons, kernel modules, disk access, or system-level accounts? → NixOS (`modules/nixos/`). Is it purely per-user configuration, packages, or dotfiles with no privileged component? → Home Manager (`modules/home/`). Does it have both a privileged component and a per-user component? → Split: implement the privileged piece in `modules/nixos/` and the per-user piece in `modules/home/`, following the existing `ft.core` / `ft.sops` / `ft.komodo` pairing pattern. State the placement decision and reasoning before proceeding.
2. Propose the option interface: feature name, option names, types, and defaults. Write no `config` yet.
3. Wait for explicit sign-off.
4. Implement the `config` block.
5. Add a VM smoke test in `ft-home/tests/vm/` (see Testing section below). Hardware-dependent, binary cache-dependent, or secrets infrastructure modules are exempt — note the exemption in the module's description.
6. Run all quality checks before committing.

---

## Option naming convention

All options are two levels deep: `ft.<feature>.enable`. Every `ft.*` option is a direct child of the `ft` attrset — there are no grouping namespaces.

| Option | Domain |
|---|---|
| `ft.core` | System core baseline (NixOS) / Home Manager foundation (HM) |
| `ft.limine` | Limine bootloader |
| `ft.cachyos` | CachyOS optimised kernel |
| `ft.cosmic` | COSMIC desktop environment |
| `ft.cosmicGreeter` | cosmic-greeter display manager |
| `ft.plasma` | KDE Plasma desktop environment with SDDM |
| `ft.plasmaBigscreen` | Plasma Bigscreen TV shell (SDDM Wayland session + HDMI-CEC) |
| `ft.diskBtrfs` | btrfs disk layout with optional LUKS |
| `ft.asus` | ASUS ROG/TUF laptop hardware support |
| `ft.vendorHw` | Vendor-specific hardware software (Lenovo Legion, Razer, MSI, Logitech, Corsair, OpenRGB, ASUS ROG, handhelds) |
| `ft.steamConfig` | Declarative per-game Steam launch options, compat tools, and non-Steam shortcuts via steam-config-nix (NixOS) / per-user counterpart (HM) |
| `ft.yubikey` | YubiKey hardware support |
| `ft.sops` | sops-nix secret management (NixOS) / per-user sops age key (HM) |
| `ft.bulkPool` | mergerfs + snapraid-btrfs bulk storage pool |
| `ft.hermesVm` | Hermes NixOS microVM |
| `ft.containers` | OCI container runtime substrate — docker/podman × rootful/rootless, real Docker Compose v2, optional Distrobox (NixOS) / user-level rootless counterpart (HM) |
| `ft.komodo` | Komodo Core + Periphery + FerretDB via docker-compose, layered on `ft.containers`, with opt-in GitOps auto-apply (NixOS) / user-level counterpart (HM) |
| `ft.microvms` | Generic microVM host infrastructure |
| `ft.nfs` | NFS client mount management |
| `ft.flatpak` | Flatpak service, Flathub remote, and Plasma Discover frontend (NixOS) / per-user declarative app list (HM) |
| `ft.ociStack` | Guest-side OCI runtime with docker-compose (used by `ft.dockervm`; slated to be replaced by `ft.containers` + `ft.komodo` in the microVM cleanup) |
| `ft.printing` | CUPS printing service |
| `ft.tailscale` | Tailscale VPN client |
| `ft.virt` | Libvirt/QEMU, Incus, VMware host |
| `ft.nixIndex` | nix-index with pre-built database and comma integration |
| `ft.cli` | The `ft` CLI helper |
| `ft.keepass` | KeePassXC secret service |
| `ft.theme` | System-wide theming via Stylix — Home Manager |
| `ft.terminal` | Terminal stack — Home Manager |
| `ft.lazyvim` | LazyVim Neovim config — Home Manager |
| `ft.dotfiles` | Dotfile symlinking — Home Manager |
| `ft.plasmaManager` | Declarative KDE Plasma settings via plasma-manager — Home Manager |
| `ft.karousel` | Karousel KWin tiling script — Home Manager |
| `ft.vicinae` | Vicinae Raycast-compatible launcher: binary cache + opt-in input-server capability wrapper (NixOS) / systemd launcher service (HM) |

Every module must declare `options.ft.<feature>.enable` using `lib.mkEnableOption`. Modules without a corresponding `enable` option are not permitted.

---

## Special options

### `ft.repoPath`

A string option set at the machine level by the consumer pointing to the absolute path of their consumer repo root on disk. `scripts/ft.just` is bundled inside fast-track-nix itself (`modules/nixos/system/just.nix` resolves it via `../../../scripts`); `ft.repoPath` is passed to `just` as `--working-directory` so recipes run against the consumer repo, not the framework. Consumers must set this if they enable `ft.cli`:

```nix
# machines/my-desktop/default.nix
_: {
  ft.repoPath = "/home/alice/ft-home";
  ft.cli.enable = true;
}
```

---

## Directory layout

```
flake.nix                  # pure wiring: inputs literal + one mkFlake call
flake-parts/
  default.nix              # auto-imports every *.nix except itself
  checks.nix               # format + lint checks (nix flake check)
  devshell.nix             # nix develop shell
  exports.nix              # lib.mkFlake, nixosModules, homeManagerModules, packages
  formatter.nix            # nix fmt entry-point
  generator.nix            # machine/user discovery → nixosConfigurations etc.
modules/
  darwin/
    default.nix            # hub: listFilesRecursive — stub, no modules yet
  nixos/
    default.nix            # hub: listFilesRecursive — no manual imports
    desktops/
    hardware/
    profiles/
    services/
    system/
  home/
    default.nix            # hub: listFilesRecursive — no manual imports
    home-core.nix          # home modules live as flat files directly here
    sops.nix
machines/
  computer/                # reference/template machine — no personal data
    default.nix
    var/                   # machine-local var (facter.json lives here)
users/
  admin/                   # reference/template users — no personal data
  guest/
staging/                   # WIP modules not yet promoted to modules/
                           # Files here are drafts; do not import from staging/
                           # in production code. Graduate to modules/ after review.
scripts/                   # ft CLI just-recipes, bundled into the framework
  ft.just                   # entry point: imports all sub-modules
  sys.just                  # daily driver: switch, pull, rollback, clean, fmt, check
  bootstrap.just             # provisioning: git-init, add-machine, secrets-init, deploy
  failover.just              # retry-with-overrides helper invoked by sys.just's switch
  mullet.just                 # package escape hatch: add/remove/list packages
  store.just                  # dotfile store management (experimental)
  drives.just                  # drive/disk utilities (mount, format, SMART checks)
  komodo.just                  # komodo-sync: generate Komodo resource-sync TOML from containers/*.yaml
```

`scripts/` is the single canonical copy of the `ft` CLI justfiles, baked into the Nix store at build time and run by the `ft.cli` wrapper (`modules/nixos/system/just.nix`) against whichever consumer repo `ft.repoPath` names. Consumer repos do not keep their own copies.

`modules/nixos/` organises modules into feature subdirectories. `modules/home/` is flat — Home Manager modules live directly as `.nix` files with no subdirectory grouping.

---

## Provisioning stack

New machines are provisioned with nixos-anywhere + disko + nixos-facter. Facter generates `machines/<name>/var/facter.json`, which the generator reads to determine the system architecture. Provisioning-related modules live under `modules/nixos/system/`.

---

## Secrets

sops-nix, age-encrypted. The sops configuration and encrypted secrets files live under `var/secrets/` in the consumer repo. SSH host key is the default age recipient. `ft.sops.useTPM` and `ft.sops.useYubikey` are available for hardware-token decryption.

---

## Quality checks

All four must pass before every commit. Fix failures; do not suppress them.

```bash
treefmt          # nixfmt (format) + deadnix --edit (remove dead bindings)
statix check .   # Nix anti-pattern linter
trufflehog git . # credential and secret scanner
nix flake check  # validates all outputs build and evaluate cleanly
```

> Note: `trufflehog` is not included in the `nix develop` devShell and must be available in your PATH separately. The CI gate runs it regardless.

---

## Testing

Testing tiers in order of implementation:

1. `nix flake check` — catches broken outputs and evaluation errors. Active.
2. Build smoke tests — a minimal consumer flake that imports ft-home and builds a machine on each supported platform (`x86_64-linux`, eventually `aarch64-linux` and `aarch64-darwin`). Partially active via the `ft-home` CI.
3. `nixosTest` VM smoke tests — one per module in `ft-home/tests/vm/`. Active: see the `VM Smoke Tests` `workflow_dispatch` workflow in `ft-home`. Required for every new testable module before the PR merges.
4. Static analysis — `statix`, `deadnix`, and `nix-eval-lints` checking option declaration quality across the module tree.

Merge a module PR only after a corresponding VM smoke test in `ft-home/tests/vm/` passes, unless the module is explicitly exempt (hardware-dependent, binary cache-dependent, or secrets infrastructure).

---

## Branch workflow

`feature` → `testing` → `main`

All pull requests target `testing`, not `main`. Changes reach `main` only after passing on `testing`.

---

## What Claude must never do

- Commit any user-specific, machine-specific, or site-specific data to ft-home.
- Create a module without a `ft.<feature>.enable` option.
- Use `lib.mkForce` except for an explicitly documented security or safety invariant.
- Put logic in `flake.nix` (mix the flake/module boundary — dendritic pattern).
- Refactor existing modules unless the task explicitly requires it.
- Expand scope beyond what was asked.
- Update any input pin without explicit instruction.
- Open a pull request targeting `main` — all PRs target `testing`.
- Merge a module PR only after a corresponding VM smoke test in `ft-home/tests/vm/` passes, unless the module is explicitly exempt (hardware-dependent, binary cache-dependent, or secrets infrastructure).
