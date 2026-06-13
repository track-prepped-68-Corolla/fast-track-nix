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

## 🖥️ TUI App — Trolley

See `ft-home/scripts/plan.md` for full architecture and development sequence.

**Target audience:** Gamers and regular PC users who prefer not to touch the terminal.  
**Packaging:** Trolley (bundles libghostty into a portable application).  
**Framework:** Python + Textual. Async subprocesses throughout.

- [x] **Option quality audit** — every `ft.*` option must have a concrete type and a `description`; replace `lib.types.anything` with specific types where possible
- [ ] **`ui-settings.nix` overlay pattern**
  - [ ] Document in README that consumer machine configs should import an optional `./ui-settings.nix` for TUI-managed overrides
  - [ ] Add `import ./ui-settings.nix` to machine `default.nix` templates (update `add-machine` scaffold in `bootstrap.just`)
  - [ ] Create initial empty `ui-settings.nix` stubs for existing machines (`strix`, `strix-vm`)
- [ ] **Darwin module tree** — generator and flake inputs support Darwin; implement the actual module side
- [ ] **Python backend (`ft/ops/`)**
  - [ ] `sys.py` — switch, pull, rollback, clean, fmt, check (async subprocess, streaming output)
  - [ ] `bootstrap.py` — git_init, add_machine, secrets_init, generate_facts, deploy
  - [ ] `mullet.py` — search (nix-index + nix search), add, remove, list, clear
  - [ ] `options.py` — option discovery via `nix eval`, `ui-settings.nix` read/write
- [ ] **Module toggle panel** (split-pane: checkboxes left, live Nix preview right)
  - [ ] Option tree from `nix eval .#nixosConfigurations.<name>.options.ft --json`
  - [ ] Dynamic widget generation from Nix option types (bool→checkbox, str→input, enum→dropdown)
  - [ ] Live `ui-settings.nix` preview with syntax highlighting
  - [ ] Write-on-confirm; in-memory updates only until confirmed
- [ ] **Maintenance screen** — switch/pull/rollback with streaming output and package diff view
- [ ] **Package manager screen** — mullet with fuzzy search, add/remove, apply
- [ ] **OOBE / provisioning wizard** — screen stack: git-init → add-machine → secrets-init → deploy
- [ ] **Dashboard** — home screen with navigation, system status summary
- [ ] **Trolley packaging** — bundle Python app + libghostty into portable application

---

## 🌐 Web Interface — Phoenix

A browser-based configuration builder and microVM launcher. The UI dynamically parses the `ft.*` module tree, presents options as form widgets, and routes the resulting config to one of two consumers: commit a new machine to the consumer repo, or spin up an ephemeral microVM without touching the repo.

The Nix module system's option declarations serve as the schema — no separate schema definition required.

**Architecture overview:**
- `flake-parts/options-schema.nix` — evaluates the module tree headlessly and exports the `ft.*` option tree as a JSON-serializable attrset (`flake.lib.ftOptionsSchema`)
- `flake-parts/machine-codegen.nix` — takes a JSON selections payload and emits a valid `machines/<name>/default.nix` string
- `flake-parts/microvm-factory.nix` — takes the same payload plus per-instance params and builds an ephemeral `lib.nixosSystem` closure without a repo commit
- `modules/nixos/services/phoenix.nix` — `ft.phoenix` NixOS module that runs the web service

**Shared contract:** both output paths consume the same JSON representation of `ft.*` selections. The UI is agnostic to which path is chosen until the user clicks "Commit" vs "Launch".

### Phase 1 — Options Schema Flake-Part

- [ ] `flake-parts/options-schema.nix`: evaluate `nixosModules.default` in a headless `lib.nixosSystem` with `_module.check = false`
- [ ] Walk `options.ft` and serialize each option to a JSON-safe shape:
  - `bool` → `{ type = "boolean"; default = false; description = "..."; }`
  - `str` → `{ type = "string"; default = ""; description = "..."; }`
  - `int` → `{ type = "integer"; default = 0; description = "..."; }`
  - `attrsOf submodule` → `{ type = "attrsOf"; schema = { ... }; }` (recursive)
  - `listOf str` → `{ type = "listOf"; item = { type = "string"; }; }`
  - `nullOr <t>` → `{ type = "nullable"; inner = <serialized t>; }`
- [ ] Export as `flake.lib.ftOptionsSchema`
- [ ] Bake into the web service package via `builtins.toJSON` so the service needs no runtime `nix eval` for the schema
- [ ] **Prerequisite:** option quality audit — every `ft.*` option must have a concrete `type` and `description`; no `lib.types.anything`

### Phase 2 — Machine Config Codegen Flake-Part

- [ ] `flake-parts/machine-codegen.nix`: `lib.mkMachineConfig { machineName, selections }`
  - Serializes the selections attrset back to formatted Nix syntax (not `builtins.toJSON` — proper Nix AST output)
  - Handles `attrsOf submodule` instances (e.g. `ft.microvms.<name>`) as nested attr blocks
  - Emits a complete `machines/<name>/default.nix` with correct `_:` or `{ config, ... }:` header
  - Includes a stub `var/facter.json` (architecture `x86_64-linux`, overridable) for the generator to pick up
- [ ] Validate round-trip: `nix eval` the generated string and confirm it evaluates cleanly
- [ ] Export as `flake.lib.mkMachineConfig`

### Phase 3 — MicroVM Factory Flake-Part

- [ ] `flake-parts/microvm-factory.nix`: `lib.mkEphemeralVm { selections, instanceParams }`
  - `selections` — feature choices from the UI (same JSON as machine codegen)
  - `instanceParams` — per-instance values not part of feature selection: IP, MAC, hostname, SSH keys, vsock CID
  - Builds inline `lib.nixosSystem` with `nixosModules.default` + selections module + instanceParams module
  - Guest includes `services.cloud-init.enable = true` so instanceParams can be injected via config drive at launch time
- [ ] Pre-built named shape packages in `flake.packages` (push to binary cache to eliminate cold-start latency):
  - [ ] `packages.<system>.microvm-base` — minimal NixOS + cloud-init + SSH, no ft.* features
  - [ ] `packages.<system>.microvm-docker` — base + `ft.ociStack`
  - [ ] `packages.<system>.microvm-komodo` — base + `ft.ociStack` + `ft.komodo`
- [ ] Export as `flake.lib.mkEphemeralVm`

### Phase 4 — `ft.phoenix` NixOS Module

- [ ] `modules/nixos/services/phoenix.nix` with options:
  - `ft.phoenix.enable` — `mkEnableOption`
  - `ft.phoenix.port` — `types.port`, default `7777`
  - `ft.phoenix.repoPath` — `types.str` — absolute path to consumer repo root (same role as `ft.repoPath`)
  - `ft.phoenix.allowedAddresses` — `types.listOf types.str`, default `["127.0.0.1" "::1"]`
- [ ] Web service binary (Go or Python/FastAPI) packaged as a Nix derivation
  - Schema JSON baked in at build time from `flake.lib.ftOptionsSchema`
  - `repoPath` injected via environment variable at activation time
- [ ] VM control endpoints: list declared VMs, start/stop/restart via `systemctl`
- [ ] Machine commit endpoint: calls `lib.mkMachineConfig`, writes files to `repoPath`, runs `git add` + `git commit`
- [ ] VM launch endpoint: calls `nix build` against the factory closure, writes cloud-init config drive, starts VM via `microvm-run`
- [ ] Per-VM resource metrics: CPU and memory from cgroups (`/sys/fs/cgroup/microvm@<name>.service/`)

### Phase 5 — Web UI

- [ ] Dynamic form generation from the baked-in schema JSON
  - `boolean` → checkbox
  - `string` → text input
  - `integer` → number input with optional min/max from type constraints
  - `attrsOf submodule` → dynamic keyed section with Add/Remove instance buttons
  - `listOf` → dynamic list with Add/Remove item buttons
  - `nullable` → optional field with enable toggle
- [ ] Two-panel layout: option form (left) + live generated Nix preview (right)
- [ ] Action bar: "Commit to Repo" (names machine, calls codegen endpoint) / "Launch Ephemeral VM" (calls factory endpoint)
- [ ] VM dashboard: running instances, start/stop controls, CPU/RAM/disk sparklines
- [ ] No JS framework dependency — plain HTML + HTMX is sufficient given the server-rendered approach

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

- [ ] Inline comments on all functions in `flake-parts/` (generator.nix is well-commented; audit remaining files)
- [ ] Consumer quickstart guide in `README.md` (machine + user + first switch)
- [ ] Module authoring guide (option naming convention, `lib.mkDefault` rule, etc.)
- [ ] Create `template/` directory with minimal consumer flake skeleton (include blank `mullet.txt`)
