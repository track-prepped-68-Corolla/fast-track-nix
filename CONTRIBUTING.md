# Contributing — Module Authoring Guide

This document covers how to add a new feature module to fast-track-nix. Read the
architecture notes in `CLAUDE.md` for the broader design rules; this guide focuses
on the implementation steps.

---

## Where modules live

| Layer | Directory | Discovery |
|---|---|---|
| NixOS | `modules/nixos/<subdir>/` | `lib.filesystem.listFilesRecursive` in `modules/nixos/default.nix` |
| Home Manager | `modules/home/` (flat) | `lib.filesystem.listFilesRecursive` in `modules/home/default.nix` |
| Darwin | `modules/darwin/` (stub) | Same pattern — not yet implemented |

Drop a `.nix` file anywhere in the appropriate tree. No import list to update.

---

## Module template

Every module follows this template exactly:

```nix
{ pkgs, lib, config, ... }:
let
  cfg = config.ft.<feature>;
in
{
  options.ft.<feature> = {
    enable = lib.mkEnableOption "<short label>" // {
      description = "<one sentence: what enabling this does>";
    };

    myOption = lib.mkOption {
      type = lib.types.str;
      default = "sensible-default";
      description = "What this option controls.";
    };
  };

  config = lib.mkIf cfg.enable {
    some.nixos.option = lib.mkDefault cfg.myOption;
  };
}
```

---

## Rules

### Option naming

All options live under `ft.<feature>` — two levels deep, flat namespace, no grouping
sub-attrs. Every module must declare `options.ft.<feature>.enable` via
`lib.mkEnableOption`.

```nix
# correct
ft.tailscale.enable = true;
ft.tailscale.authKeyFile = "/run/secrets/ts-key";

# wrong — no grouping namespace
ft.network.tailscale.enable = true;
```

Every `mkOption` must include both `type` and `description`.

### `lib.mkDefault` everywhere in `config`

Wrap every value in the `config` block with `lib.mkDefault` so consumers can
override it without needing `lib.mkForce`:

```nix
config = lib.mkIf cfg.enable {
  services.tailscale.enable = lib.mkDefault true;   # consumer can override
};
```

`lib.mkForce` is reserved exclusively for security or safety invariants that
**must not** be overridden. Add a comment explaining why when you use it.

### Bind `cfg` at the top

```nix
let cfg = config.ft.<feature>; in  # correct

# wrong — repeating the path inside config
config = lib.mkIf config.ft.<feature>.enable { ... };
```

### Prefer `lib.optional*` over `if/else`

```nix
# correct
environment.systemPackages = lib.optionals cfg.enableExtra [ pkgs.foo pkgs.bar ];

# wrong
environment.systemPackages = if cfg.enableExtra then [ pkgs.foo pkgs.bar ] else [];
```

### `with pkgs;` scope restriction

`with pkgs;` is acceptable **only** inside list literals. Never open it at module scope.

```nix
# correct
environment.systemPackages = with pkgs; [ git curl wget ];

# wrong
{ with pkgs; environment.systemPackages = [ git curl wget ]; }
```

### No intra-framework imports

Do not add `imports` inside a feature module to pull in another framework module.
Cross-module dependencies are satisfied by the NixOS module system automatically.
The only permitted `imports` inside a module are upstream input modules:

```nix
# correct — importing an external input module
imports = [ inputs.sops-nix.nixosModules.sops ];

# wrong — importing another ft-home module
imports = [ ../system/core.nix ];
```

---

## Workflow for a new module

1. **Propose the interface** — option names, types, defaults, and a one-line
   description per option. Submit a PR with the `options` block only; no `config`
   yet. Wait for review sign-off.

2. **Implement `config`** — add the `config = lib.mkIf cfg.enable { ... }` block.
   All values use `lib.mkDefault` unless they are security invariants.

3. **Add a VM smoke test** — create `tests/vm/vm-<feature>.nix` in `ft-testing`
   and register it in `tests/vm/default.nix` and `.github/workflows/vm-tests.yml`.
   The test must assert at least one runtime effect (service active, binary on PATH,
   file present) — not just that the config evaluates. See `ft-testing/tests/vm/`
   for examples.

   Modules that are exempt from VM tests (note the exemption in the module's
   `description`):
   - Hardware-dependent (real block devices, specific firmware)
   - Binary cache-dependent (CachyOS, nix-index-database)
   - Secrets infrastructure (sops key derivation)

4. **Run quality checks** before every commit:

   ```bash
   treefmt          # nixfmt + deadnix
   statix check .   # anti-pattern linter
   trufflehog git . # credential scanner (must be in PATH separately)
   nix flake check  # build all check derivations
   ```

5. **Open a PR against `testing`**, not `main`. The PR description should include
   the option interface, a brief rationale, and a link to the corresponding VM
   smoke test PR in `ft-testing`.

---

## Branch workflow

```
feature → testing → main
```

All PRs target `testing`. Changes reach `main` only after CI passes on `testing`.
Never open a PR directly against `main`.
