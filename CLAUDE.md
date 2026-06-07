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

`flake.nix` exposes two things: `lib.mkFlake` (delegates to `lib/generator.nix`) and the module hub entry-points (`nixosModules.default`, `homeManagerModules.default`). No evaluation logic, no config generation, no module code lives in `flake.nix`.

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

Consumers never need to declare the system manually; facter.json is the source of truth.

fast-track-nix itself has no `machines/` entries — the generator produces empty outputs against the framework repo. The real exercise of the generator is `ft-home`'s CI, which runs against `machines/strix`.

---

## Module anatomy

Every module follows this template exactly:

```nix
{ pkgs, lib, config, ... }:
let
  cfg = config.ft.<namespace>.<feature>;
in
{
  options.ft.<namespace>.<feature> = {
    enable = lib.mkEnableOption "<short label>" // {
      description = "<one sentence describing what enabling this does>";
    };
    # additional mkOption declarations — always include `type` and `description`
  };

  config = lib.mkIf cfg.enable {
    # every value wrapped in lib.mkDefault unless it is a security invariant
  };
}
```

### Rules that apply to every module

- Bind `cfg = config.ft.<namespace>.<feature>;` at the top with `let-in`. Never repeat the full attribute path inside the `config` block.
- Prefer `inherit (cfg) foo bar;` over `foo = cfg.foo; bar = cfg.bar;` repetition.
- All `config` values use `lib.mkDefault` so consumers can override without `lib.mkForce`.
- `lib.mkForce` is reserved exclusively for security or safety invariants that must not be overridden. Comment the reason when used.
- `lib.optional` / `lib.optionals` / `lib.optionalAttrs` instead of `if … then … else []`.
- `with pkgs;` is acceptable only inside list literals (e.g., `environment.systemPackages = with pkgs; [ … ]`). Never open `with pkgs;` at module scope.
- No `imports` inside individual feature modules unless pulling in an upstream input module (e.g., `inputs.sops-nix.nixosModules.sops`). Internal cross-module dependencies are handled by the module system, not by explicit imports.

### Adding a module

Drop a `.nix` file anywhere under `modules/nixos/` or `modules/home/`. The `default.nix` hub in each uses `lib.filesystem.listFilesRecursive` — no imports list to update. The file is discovered and evaluated automatically on the next build.

**Workflow for new modules:**
1. Propose the option interface: namespace, option names, types, and defaults. Write no `config` yet.
2. Wait for explicit sign-off.
3. Implement the `config` block.
4. Add a VM smoke test in `ft-home/tests/vm/` (see Testing section below). Hardware-dependent, binary cache-dependent, or secrets infrastructure modules are exempt — note the exemption in the module's description.
5. Run all quality checks before committing.

---

## Option naming convention

New modules should be exactly three levels deep: `ft.<namespace>.<feature>.enable`. Several existing modules predate this convention and use two levels (e.g., `ft.cli.enable`, `ft.keepass.enable`, `ft.theme.enable`, `ft.terminal.enable`) — these are grandfathered in and should not be renamed without a migration plan.

| Namespace | Domain |
|---|---|
| `ft.system.*` | Core OS baseline |
| `ft.boot.*` | Bootloader configuration |
| `ft.kernel.*` | Kernel variants |
| `ft.desktop.*` | Desktop environments |
| `ft.hardware.*` | Hardware support (GPU, YubiKey, disk layout) |
| `ft.profiles.*` | Compound use-case profiles |
| `ft.services.*` | System services (printing, NFS, Tailscale, etc.) |
| `ft.programs.*` | Program-level features (nix-index) |
| `ft.security.*` | Security tooling and secrets |
| `ft.cli` | The `ft` CLI helper (two-level; grandfathered) |
| `ft.mullet` | Imperative package escape hatch (two-level; grandfathered from consumer) |
| `ft.rclone` | rclone cloud storage tooling (two-level; grandfathered from consumer) |
| `ft.keepass` | KeePassXC secret service (two-level; grandfathered) |
| `ft.theme` | System-wide theming via Stylix — Home Manager (two-level; grandfathered) |
| `ft.terminal` | Terminal stack — Home Manager (two-level; grandfathered) |
| `ft.lazyvim` | LazyVim Neovim config — Home Manager (two-level; grandfathered) |
| `ft.dotfiles` | Dotfile symlinking — Home Manager (two-level; grandfathered) |
| `ft.home.sops` | Per-user sops age key — Home Manager |
| `ft.cosmic` | COSMIC desktop theming — Home Manager (two-level; grandfathered) |

New namespaces require a comment in the module justifying why none of the above apply.

Every module must declare `options.ft.<namespace>.<feature>.enable` using `lib.mkEnableOption`. Modules without a corresponding `enable` option are not permitted.

---

## Special options

### `ft.repoPath`

A string option set at the machine level by the consumer pointing to the absolute path of their consumer repo root on disk. Required by `ft.cli.enable` to locate `scripts/ft.just` at runtime. Consumers must set this if they enable `ft.cli`:

```nix
# machines/my-desktop/default.nix
_: {
  ft.repoPath = "/home/alice/nixos-config";
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
    host-facts.nix
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
```

`modules/nixos/` organises modules into feature subdirectories. `modules/home/` is flat — Home Manager modules live directly as `.nix` files with no subdirectory grouping.

---

## Provisioning stack

New machines are provisioned with nixos-anywhere + disko + nixos-facter. Facter generates `machines/<name>/var/facter.json`, which the generator reads to determine the system architecture. Provisioning-related modules live under `modules/nixos/system/`.

---

## Secrets

sops-nix, age-encrypted. The sops configuration and encrypted secrets files live under `var/secrets/` in the consumer repo. SSH host key is the default age recipient. `ft.security.sops.useTPM` and `ft.security.sops.useYubikey` are available for hardware-token decryption.

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
- Create a module without a `ft.<namespace>.<feature>.enable` option.
- Use `lib.mkForce` except for an explicitly documented security or safety invariant.
- Put logic in `flake.nix` (mix the flake/module boundary — dendritic pattern).
- Refactor existing modules unless the task explicitly requires it.
- Expand scope beyond what was asked.
- Update any input pin without explicit instruction.
- Open a pull request targeting `main` — all PRs target `testing`.
- Merge a module PR only after a corresponding VM smoke test in `ft-home/tests/vm/` passes, unless the module is explicitly exempt (hardware-dependent, binary cache-dependent, or secrets infrastructure).
