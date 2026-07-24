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
  - [ ] Pre-built named shapes in `flake.packages` (binary-cached to eliminate cold-start latency): `microvm-base`, `microvm-docker` (`ft.containers`), `microvm-komodo` (`ft.containers` + `ft.komodo`)

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
- [ ] **Non-Nix machine registry (`gitops/`)** — standardise a `gitops/` folder convention for consumer repos to register non-NixOS machines alongside their capture/restore scripts
  - [ ] Define `gitops/<platform>/<name>/` directory structure: captured config blob + a `machine.nix` metadata file (hostname, address, platform tag, Guacamole connection type)
  - [ ] `machine.nix` is the single source of truth consumed by both the gitops scripts and `ft.homepage` inventory generation — adding a device to `gitops/` is sufficient to surface it everywhere
  - [ ] Publish the folder convention and `machine.nix` schema in `ft-testing` as a template consumers can adopt
- [ ] **`ft.homepage`** — Homepage dashboard for machine inventory, service links, and system stats widgets
  - [ ] `services.homepage-dashboard` with configurable port and YAML config path
  - [ ] Auto-generate the services config from the consumer's machine inventory — each entry in `nixosConfigurations` becomes a Homepage service card with a Guacamole link, so adding a machine to `machines/` surfaces it in the dashboard without manual config
  - [ ] Pull non-Nix machines from the consumer's `gitops/` registry (`machine.nix` entries) into the same inventory, so the dashboard reflects the full fleet regardless of platform
  - [ ] Link out to Guacamole per-machine connections via URL widgets
- [ ] **`ft.guacamole`** — Clientless SSH / VNC / RDP remote access via Apache Guacamole (replaces need for a separate per-protocol web client)
  - [ ] Verify nixpkgs `services.guacamole-server` / `services.guacamole-client` module state before implementing — historically had maintenance gaps
  - [ ] Requires PostgreSQL — document dependency on `services.postgresql`
  - [ ] VM console access (VNC) depends on `ft.virt` (libvirt VNC passthrough)

---

## 🚀 Forgejo CI Migration

Migration of all GitHub Actions workflows to Forgejo Actions. No hard blockers — the core Nix pipeline is portable; the GitHub-specific integrations need adaptation rather than replacement.

### One-time infrastructure
- [ ] Set up self-hosted `act_runner` and register against Forgejo instance
- [ ] Configure KVM passthrough on runner host (required for `vm-tests.yml` in ft-testing)
- [ ] Re-create all secrets (`ANTHROPIC_API_KEY`, `RENOVATE_TOKEN`) in Forgejo

### Mechanical workflow ports
- [ ] **`ci.yml` ×4** (fast-track-nix, ft-testing, ft-home, ft-template) — replace `actions/github-script` "Tag Claude on failure" step with a `curl` POST to Forgejo issues API; all nix steps unchanged
- [ ] **`module-docs.yml`** (fast-track-nix) — works as-is; update runner label to match `act_runner` configuration
- [ ] **`vm-tests.yml`** (ft-testing) — works as-is with KVM runner; update runner label
- [ ] **`nix-update.yml`** (fast-track-nix) — replace `gh workflow run ci.yml` with a `curl` POST to Forgejo workflow dispatch API (`POST /api/v1/repos/{owner}/{repo}/actions/workflows/ci.yml/dispatches`)
- [ ] **`renovate.yml`** (fast-track-nix) — drop the workflow; deploy Renovate as a standalone service pointing at the Forgejo instance (`platform: forgejo` in Renovate config); `renovate.json` carries over unchanged

### Agent-dependent ports
- [ ] **`claude.yml` ×2** (fast-track-nix, ft-home) — replace `anthropic/claude-code-action` step with self-hosted agent invocation; agent must handle Forgejo API for comment reads/writes and git push
- [ ] **`claude-review-on-coderabbit.yml` ×2** (fast-track-nix, ft-home) — replace `actions/github-script` comment step with `curl` to Forgejo issues API; verify CodeRabbit bot username on Forgejo instance matches the `if:` condition

---

## 🔐 Security & Secrets

- [ ] Diceware generator for high-entropy initial user passphrases
- [ ] Script programmatic creation of a KeePassXC (`.kdbx`) vault using the Diceware password as master key
- [ ] Configure `.gitignore` to explicitly allow the `.kdbx` vault file for local version-controlled redundancy
- [ ] `systemd-userd` integration

---

## 💻 Hardware & Vendors

- [x] ASUS hardware support
- [x] **Support other vendors:**
  - [x] Review `nixos-hardware` for common vendor profiles (Lenovo, Dell, etc.)
  - [x] Scaffold a generic vendor module structure for toggling vendor-specific quirks
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
- [x] **Remove hard-coded defaults from framework modules** (`modules/nixos/system/core.nix`):
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
- [ ] **`ft.jj` module** — optional, gated colocated Jujutsu setup for consumers who want jj ergonomics on top of the existing git-backed repo
  - [ ] `ft.jj.enable` runs `jj git init --colocate` against `ft.repoPath` (idempotent — skip if `.jj/` already exists) and installs the `jj` package
  - [ ] Configure `jj config` user name/email (reuse the same identity already set up for git via `bootstrap.just`'s `git-init`, rather than asking twice)
  - [ ] Document the colocated requirement (`.git/` stays authoritative for GitHub/CI/trufflehog; `jj` is a layer on top, not a replacement)
  - [ ] Decide on a bookmark-naming convention (jj bookmarks don't auto-follow `@` like git branches) and document the `jj bookmark set` + `jj git push --bookmark` flow
- [ ] **jj-flavored `scripts/*.just` rework**, gated on `ft.jj.enable` (existing git-based recipes remain the default when disabled)
  - [ ] `_stage`/`_diff-src` → `jj status`/`jj diff` equivalents (note: still needed as a forcing op so Nix's git-tracked-files source filter sees new files, not just for jj's own state)
  - [ ] `sys.just`'s `switch` commit step → `jj describe -m` + `jj new` instead of `git commit`
  - [ ] `pull`/`push` → `jj git fetch` + rebase onto the upstream bookmark, then explicit `jj bookmark set` + `jj git push --bookmark`
  - [ ] Collapse `bootstrap.just`'s six repeated stage+conditional-commit call sites (`git-init`, `tailscale-init`, `add-machine`, `secrets-init`, `generate-facts`, the `deploy`/`deploy-local` disk-device correction) into a single `_checkpoint message +paths` helper built on `jj commit -- paths`
- [ ] **Convert `flake-parts/devshell.nix` to devenv** — replace `pkgs.mkShell` with `devenv.flakeModule` so per-repo `.envrc`/`devenv.nix` can export dev-only markers (e.g. the jj/git auto-refresh marker below) without touching the OS-scoped `ft.cli`/`ft.jj` modules; project-scoped (devenv) vs OS-scoped (`ft.cli`/`ft.jj`) tooling stay deliberately parallel, not merged
  - [ ] While converting, fix devShell package drift: `convco` is unused (no `sys.just` recipe calls it); `trufflehog` is required by the quality-check gate but currently excluded
  - [ ] Refine the marker-consuming auto-refresh function (a global dotfiles `precmd` hook riding on direnv's existing per-line hook, gated on the `FT_VCS_AUTOREFRESH` marker exported by each opted-in repo's `.envrc`) for git/jj robustness — must no-op during an in-progress rebase/merge and run non-blocking

---

## 🧹 Container Module Cleanup / Redundancy

> From a container-module inventory (docker / podman / komodo) across
> fast-track-nix, ft-home, ft-testing. The Komodo/runtime consolidation and the
> microVM Phase 1 cleanup are done; the Phase 2 factory refactor remains.

- [x] **Consolidate the container/Komodo modules** — collapsed the three
  overlapping Komodo implementations into one runtime substrate plus one app,
  each split only by module system: `ft.containers` (NixOS + HM;
  docker/podman × rootful/rootless, real Compose v2, optional Distrobox) and
  `ft.komodo` (NixOS + HM; the upstream Komodo compose + FerretDB stack layered
  on `ft.containers`, credentials in sops via `ft.komodo.sopsEnv`). Folded
  `ft.podmanRootless` into `ft.containers` and deleted it. The `ft.komodo` pair
  is now the supported, cooperating docker-compose implementation — not to be
  removed.
- [x] **MicroVM cleanup — Phase 1** — retargeted `ft.dockervm`'s guest onto
  `ft.containers` + `ft.komodo`; deleted `ft.ociStack` (`oci-stack.nix`),
  `ft.guacamole` (`guacamole.nix`), and `ft.hermesVm` (`microvm-hermes.nix`,
  dropped as a failed experiment) along with the now-unused `hermes-agent`
  flake input. Added `ft.komodo.assumeSopsConfigured` so the guest's
  directly-configured sops-nix passes the [secrets]-tier assertion.
- [ ] **MicroVM cleanup — Phase 2 (factory refactor)** — pull VM definitions out
  of the host module system: standalone, cacheable VM `nixosConfigurations`
  discovered from a `vms/` directory (analogous to `machines/`), with the host
  slimmed to bridge/NAT/TAP + attach-by-reference. Removes the inline-guest
  recursion fragility and unlocks the Trolley ephemeral-VM / named-shapes
  roadmap. Open decision before starting: per-VM network injection — DHCP on the
  bridge (preferred) vs cloud-init.

---

## 📖 Documentation

- [x] Inline comments on all functions in `flake-parts/` (generator.nix is well-commented; audit remaining files)
- [x] Consumer quickstart guide in `README.md` (machine + user + first switch)
- [x] Module authoring guide (option naming convention, `lib.mkDefault` rule, etc.)
- [x] Create `template/` directory with minimal consumer flake skeleton (include blank `mullet.txt`)
- [ ] **Module docs custom formatter** — replace `nixosOptionsDoc`'s flat CommonMark output with a custom renderer that groups `ft.*` options by feature (`##` per feature), emits a table of contents, and adds one-line feature summaries; source from `optionsJSON` rather than `optionsCommonMark`
