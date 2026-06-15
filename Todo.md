# fast-track-nix — Consolidated Todo

> Merged from `fast-track-nix/testing` and `ft-home/testing`.

---

## ✅ Done

### Framework (fast-track-nix)
- [x] Wire up all flake inputs
- [x] Machine and user auto-discovery via `lib/generator.nix`
- [x] NixOS module hub (`modules/nixos/default.nix` — `listFilesRecursive`)
- [x] Home Manager module hub (`modules/home/default.nix` — `listFilesRecursive`)
- [x] Replace lanzaboote with nixos-facter; migrate bootloader to Limine
- [x] sops-nix wired into core module system
- [x] `ft.cli` module — installs `just` and thin `ft` wrapper pointing to consumer's `scripts/ft.just`
- [x] treefmt + nixfmt + statix + deadnix wired into CI (`nix flake check`)
- [x] `README.md` explaining framework consumption
- [x] `ft.sops` — ssh-to-age pipeline: derives age key from `/etc/ssh/ssh_host_ed25519_key` silently on boot (`modules/nixos/system/sops.nix`)
- [x] Graceful degradation for secrets via `ft.sops.enable` (`mkIf` guards entire sops config)
- [x] No hardcoded U2F keys in framework — consumers supply their own via `ft.yubikey.u2fMapping`
- [x] Create a user-level Komodo module — `modules/home/komodo.nix` (`ft.komodo.enable`)

### Consumer (ft-home)
- [x] Wire up all flake inputs
- [x] Create magic folder functions for hosts and homes
- [x] Create magic collator files for host and home modules
- [x] Create a home module for magic `mkOutOfStoreSymlink` folder functions
- [x] Externalize generator logic into `lib/generator.nix`
- [x] Purge modules and bring back MVP; import and verify core NixOS and Home Manager modules
- [x] Implement "The Mullet" (consumer side) — `mullet.nix` ingests a flat `mullet.txt` for imperative packages
- [x] Set Atkinson Hyperlegible as the default system font via Stylix
- [x] Swap bootloader to Limine; remove lanzaboote; add facter
- [x] Set up facter modules and GPU module *(done in ft-home consumer: `modules/nixos/hardware/`)*
- [x] Bring in just scripts and modify as needed
- [x] Add `sops-nix` to flake inputs and wire into the core module system
- [x] Export module collators via `nixosModules.default` and `homeManagerModules.default`
- [x] Write `README.md` explaining framework consumption
- [x] Clean up and standardize the `justfile` scripts:
  - [x] Delete legacy `.justfile`; make `ft.just` a thin entry point (imports + aliases only)
  - [x] Split into modules: `sys.just`, `bootstrap.just`, `mullet.just`, `store.just`
  - [x] Fix `add-machine` template to match actual machine structure
  - [x] Fix `mullet.just` path — moved `mullet.txt` to `users/<user>/var/mullet.txt`
  - [x] Port `home-switch` with correct just parameter syntax
  - [x] Fix secrets and bootstrap paths to match `var/secrets/` layout

---

## 🏗️ Module Ports (Consumer → Framework)

Items currently in ft-home that belong in fast-track-nix as proper `ft.*` modules.

- [x] **`ft.mullet`** — port imperative package escape hatch to framework
  - [x] Move `mullet.nix` from ft-home `modules/nixos/apps/` into fast-track-nix `modules/nixos/apps/`
  - [x] Expose `ft.mullet.enable` and `ft.mullet.sourcePath` options
  - [x] Consumer sets `ft.mullet.filePath`; remove local `mullet.nix` from ft-home
  - [x] `mullet.just` runtime path convention (`users/$USER/var/mullet.txt`) matches `ft.mullet.sourcePath` pattern — no script change needed
  - [x] Export `nixosModules.mullet` as a standalone flake output
- [x] **`ft.facter`** — port nixos-facter hardware report ingestion to framework
  - [x] Move `facter.nix` from ft-home into fast-track-nix `modules/nixos/hardware/facter.nix`
  - [x] Expose `ft.facter.enable` and `ft.facter.reportPath` options
  - [x] Remove local copy from ft-home once framework version is stable
- [x] **`ft.gpu`** — port generic GPU vendor detection to framework
  - [x] Move `gpu.nix` from ft-home into fast-track-nix `modules/nixos/hardware/gpu.nix`
  - [x] Support AMD, Intel, NVIDIA, integrated; detect from facter output where possible
  - [x] Remove local copy from ft-home once framework version is stable

---

## 🔌 Flake API

- [x] Export `ft` CLI wrapper via `packages.default` using `writeShellApplication`
  - [x] `runtimeInputs`: `just`, `glow`, `nh`, `git`, `nvd`, `delta`, `trufflehog` — zero global dependency footprint
- [x] Export `nixosModules.mullet` standalone
- [ ] **External base path:** refactor `mkOutOfStoreSymlink` to accept `absoluteBasePath` from the consumer

---

## 🖥️ UI — Trolley

A configuration and management interface for consumers. The Nix module system's option declarations serve as the schema — no separate schema definition required. Config selections route to one of two outputs: commit a new machine to the consumer repo, or spin up an ephemeral microVM without touching the repo.

### Framework Prerequisites

- [x] **Option quality audit** — every `ft.*` option must have a concrete type and `description`
- [ ] **`ui-settings.nix` overlay pattern**
  - [ ] Document that consumer machine configs should import an optional `./ui-settings.nix` for UI-managed overrides
  - [ ] Add `import ./ui-settings.nix` to machine `default.nix` templates (update `add-machine` scaffold in `bootstrap.just`)
  - [ ] Create initial empty `ui-settings.nix` stubs for existing machines
- [ ] **Darwin module tree** — generator and flake inputs support Darwin; implement the actual module side
- [ ] **`flake-parts/options-schema.nix`** — evaluate `nixosModules.default` headlessly, walk `options.ft`, serialize each option to a JSON-safe shape (`bool`, `str`, `int`, `attrsOf submodule`, `listOf`, `nullOr`); bake into the service package at build time so no runtime `nix eval` is needed for the schema; export as `flake.lib.ftOptionsSchema`
- [ ] **`flake-parts/machine-codegen.nix`** — `lib.mkMachineConfig { machineName, selections }`: serialize selections to proper Nix syntax (not JSON), emit a complete `machines/<name>/default.nix` with stub `var/facter.json`, validate round-trip with `nix eval`; export as `flake.lib.mkMachineConfig`
- [ ] **`flake-parts/microvm-factory.nix`** — `lib.mkEphemeralVm { selections, instanceParams }`: build inline `lib.nixosSystem`, inject per-instance params (IP, MAC, hostname, SSH keys, vsock CID) via cloud-init config drive at launch; export as `flake.lib.mkEphemeralVm`
  - [ ] Pre-built named shapes in `flake.packages` (binary-cached to eliminate cold-start latency): `microvm-base`, `microvm-docker` (`ft.ociStack`), `microvm-komodo` (`ft.ociStack` + `ft.komodo`)

### Features

- [ ] **Module toggle panel** — option tree from `nix eval .#nixosConfigurations.<name>.options.ft`, widget per type (bool→toggle, str→input, enum→dropdown, attrsOf→keyed section with Add/Remove, listOf→dynamic list); write-on-confirm with in-memory staging
- [ ] **Live Nix preview** — real-time `ui-settings.nix` output with syntax highlighting, updated as options change
- [ ] **Maintenance** — switch/pull/rollback/clean/fmt/check with streaming output and package diff view
- [ ] **Package manager** — mullet: fuzzy search, add/remove, apply
- [ ] **OOBE / provisioning wizard** — git-init → add-machine → secrets-init → deploy flow
- [ ] **VM dashboard** — running microVM instances, start/stop/restart, per-VM CPU/RAM metrics from cgroups (`/sys/fs/cgroup/microvm@<name>.service/`)
- [ ] **Machine commit** — write `machines/<name>/` to `repoPath`, run `git add` + `git commit`
- [ ] **Ephemeral VM launch** — build from factory closure, write cloud-init config drive, start via `microvm-run`
- [ ] **Dashboard** — home screen with navigation and system status summary

### Service Module

- [ ] **`ft.trolley`** NixOS module (`modules/nixos/services/trolley.nix`) with options: `enable`, `port` (default `7777`), `repoPath`, `allowedAddresses` (default `["127.0.0.1" "::1"]`); schema JSON baked in at build time from `flake.lib.ftOptionsSchema`

### Packaging

- [ ] Bundle as a portable, self-contained application

---

## 🔁 Self-Hosted GitOps Stack

- [ ] **`ft.forgejo`** — Forgejo Git forge + optional Actions runner for consumer repo hosting and GitOps push-to-deploy
  - [ ] `services.forgejo` with sensible defaults (data dir, DB, domain)
  - [ ] Optional Forgejo Actions runner (`ft.forgejo.runner.enable`) for `nixos-rebuild switch` on push
- [ ] **`ft.netdata`** — Netdata monitoring agent with optional parent-node streaming
  - [ ] `services.netdata` per-machine agent
  - [ ] `ft.netdata.parentUrl` option for streaming metrics to a central Netdata parent node
- [ ] **`ft.homepage`** — Homepage dashboard for machine inventory, service links, and system stats widgets
  - [ ] `services.homepage-dashboard` with configurable port and YAML config path
  - [ ] Auto-generate the services config from the consumer's machine inventory — each entry in `nixosConfigurations` becomes a Homepage service card with a Guacamole link, so adding a machine to `machines/` surfaces it in the dashboard without manual config
  - [ ] Link out to Guacamole per-machine connections via URL widgets
- [ ] **`ft.guacamole`** — Clientless SSH / VNC / RDP remote access via Apache Guacamole (replaces need for a separate per-protocol web client)
  - [ ] Verify nixpkgs `services.guacamole-server` / `services.guacamole-client` module state before implementing — historically had maintenance gaps
  - [ ] Requires PostgreSQL — document dependency on `services.postgresql`
  - [ ] VM console access (VNC) depends on `ft.virt` (libvirt VNC passthrough)

---

## 🔐 Security & Secrets

- [ ] Diceware generator for high-entropy initial user passphrases
- [ ] Script programmatic creation of a KeePassXC (`.kdbx`) vault using the Diceware password as master key
- [ ] Configure `.gitignore` to explicitly allow the `.kdbx` vault file for local version-controlled redundancy
- [ ] `systemd-userd` integration

---

## 💻 Hardware & Vendors

- [x] ASUS hardware support
- [ ] **Support other vendors:**
  - [ ] Review `nixos-hardware` for common vendor profiles (Lenovo, Dell, etc.)
  - [ ] Scaffold a generic vendor module structure for toggling vendor-specific quirks
  - [ ] Implement and test at least one alternative vendor configuration

---

## 👁️ Ergonomics & Accessibility (The "Chaotic Good" Stack)

- [ ] **Visual & Circadian Automation:**
  - [ ] Build the Matugen → Stylix pipeline for Base24 HCT contrast manipulation
  - [ ] Integrate Gammastep for circadian color temperature shifting
  - [ ] Configure `ddcutil` for hardware backlight control (with a silent fallback to Wayland brightness shaders)
- [ ] **Typography & Spatial Scaling:**
  - [ ] Script dynamic UI padding and text scaling based on time of day/fatigue levels
- [ ] **Kinematics & Input (RSI Prevention):**
  - [ ] Set up `kanata` for kernel-level Home Row Mods
  - [ ] Integrate `warpd` for geometric, keyboard-driven mouse emulation
- [ ] **Auditory & Attention Management:**
  - [ ] Set up local offline STT (Whisper.cpp) and TTS (Piper) tied to global Wayland hotkeys
  - [ ] Create a DBus notification interceptor script (`mako` or `dunst`) for context-aware routing and squashing during deep work

---

## 👥 User Provisioning & Environment

- [ ] Create a script that creates generic home folders for new users
- [ ] Create a script that runs the first home-manager switch on users without an existing profile
- [ ] Create mackup dotfile sync script

---

## 🌐 Public Release

### 🧹 Sanitization & Security
- [x] Audit all modules and reference configs for personal data (usernames, hostnames, paths, private IPs)
  - [x] Fix hardcoded wallpaper path in `stylix.nix` — expose as a consumer-supplied option instead
- [x] Replace hardcoded user strings with variable references (e.g., `config.home.username`) — no replacements needed; all "admin" strings are generic defaults or reference-config placeholders
- [x] Move highly specific private modules out of the repo entirely
- [ ] **Remove hard-coded defaults from framework modules** (`modules/nixos/system/core.nix`):
  - [x] `ft.core`: Remove `time.timeZone = "America/New_York"` default — require consumers to set their own
  - [x] `ft.core`: Remove hard-coded `system.stateVersion = "24.05"` — consumers must own this value
  - [x] `ft.users`: Remove `initialPassword` default from `user.nix` — require sops or an explicit consumer option
- [ ] **Crucial:** Reset Git history right before publishing

### 🔌 Flake API & Exports
*(see Flake API section above)*

### 📦 Testing
- [x] Add `nixosTest` skeletons for each module (one per module, minimal assertions)
- [x] Build smoke test: minimal consumer flake that builds on `x86_64-linux`

---

## 👾 Scripts & CLI

- [ ] Write a wrapper for the Lix fork of the Determinate Systems installer
- [ ] **Graceful Degradation:** Wrap git integrations (`git diff`, `delta`, auto-commits) in `git rev-parse --is-inside-work-tree` checks

---

## 📖 Documentation

- [x] Inline comments on all functions in `flake-parts/` (generator.nix is well-commented; audit remaining files)
- [x] Consumer quickstart guide in `README.md` (machine + user + first switch)
- [x] Module authoring guide (option naming convention, `lib.mkDefault` rule, etc.)
- [x] Create `template/` directory with minimal consumer flake skeleton (include blank `mullet.txt`)
