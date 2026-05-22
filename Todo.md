# fast-track-nix — Todo

## ✅ Done

- [x] Wire up all flake inputs
- [x] Machine and user auto-discovery via `lib/generator.nix`
- [x] NixOS module hub (`modules/nixos/default.nix` — `listFilesRecursive`)
- [x] Home Manager module hub (`modules/home/default.nix` — `listFilesRecursive`)
- [x] Replace lanzaboote with nixos-facter; migrate bootloader to Limine
- [x] sops-nix wired into core module system
- [x] `ft.cli` module — installs `just` and thin `ft` wrapper pointing to consumer's `scripts/ft.just`
- [x] treefmt + nixfmt + statix + deadnix wired into CI (`nix flake check`)
- [x] `README.md` explaining framework consumption

---

## 🏗️ Module Ports (consumer → framework)

Items currently implemented in ft-home that belong here as proper `ft.*` modules.

- [ ] **`ft.mullet`** — imperative package escape hatch
  - [ ] Move `mullet.nix` from ft-home `modules/nixos/apps/` into `modules/nixos/system/`.
  - [ ] Option: `ft.mullet.enable`, `ft.mullet.sourcePath` (path, required when enabled).
  - [ ] Export `nixosModules.mullet` as a standalone flake output.
- [ ] **`ft.hardware.facter`** — nixos-facter hardware report ingestion
  - [ ] Move from ft-home consumer into `modules/nixos/hardware/facter.nix`.
  - [ ] Option: `ft.hardware.facter.enable`, `ft.hardware.facter.reportPath`.
- [ ] **`ft.hardware.gpu`** — generic GPU vendor detection
  - [ ] Move from ft-home consumer into `modules/nixos/hardware/gpu.nix`.
  - [ ] Support AMD, Intel, NVIDIA, integrated. Detect from facter output where possible.

---

## 🔌 Flake API

- [ ] Export additional library utilities under `outputs.lib` (currently only `lib.mkFlake`).
- [ ] Export `ft` CLI wrapper via `packages.default` using `writeShellApplication`.
  - [ ] `runtimeInputs`: `just`, `nh`, `git`, `nvd`, `delta`, `trufflehog` — zero global dependency footprint.
- [ ] Export `nixosModules.mullet` standalone *(blocked on mullet port above)*.
- [ ] **External base path:** refactor `mkOutOfStoreSymlink` to accept `absoluteBasePath` from the consumer.

---

## 🖥️ TUI App Support (fast-track-nix side)

The ft-home consumer is building a Trolley-packaged TUI. The framework needs to hold up
its end for option introspection to work correctly.

- [ ] **Option quality audit** — every `ft.*` option must have a concrete type and a
  `description`. Audit all modules; replace `lib.types.anything` with specific types where possible.
  Vague types produce vague widgets in the TUI.
- [ ] **`ui-settings.nix` pattern** — document in README that consumer machine configs should
  import an optional `./ui-settings.nix` for TUI-managed overrides. Add to reference machine template.
- [ ] **Darwin module tree** — generator declares Darwin support; implement the module side.

---

## 🌐 Public Release

- [ ] Audit all modules and reference configs for personal data (usernames, paths, IPs).
- [ ] Replace hardcoded user strings with `config.home.username` references.
- [ ] Create `template/` directory with minimal consumer flake skeleton.
- [ ] Add `nixosTest` skeletons for each module (one per module, minimal assertions).
- [ ] Build smoke test: minimal consumer flake that builds on `x86_64-linux`.

---

## 🔐 Security & Secrets

- [ ] `ft.security.sops` — `ssh-to-age` pipeline: derive age key from SSH host key silently on boot.
- [ ] Diceware generator for high-entropy initial user passphrases.
- [ ] KeePassXC vault creation scripted from Diceware password.
- [ ] `systemd-userd` integration.

---

## 💻 Hardware & Vendors

- [ ] ASUS hardware support.
- [ ] Survey `nixos-hardware` for Lenovo, Dell, and other common vendor profiles.
- [ ] Scaffold generic vendor module structure for toggling vendor-specific quirks.

---

## 📖 Documentation

- [ ] Inline comments on all `lib/` functions.
- [ ] Consumer quickstart guide in `README.md` (machine + user + first switch).
- [ ] Module authoring guide (the option naming convention, `lib.mkDefault` rule, etc.).
