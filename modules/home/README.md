# Module Options

## Table of Contents

- [ft.atuin](#ftatuin) — Replaces zsh's plain history search with atuin, which stores your shell history in a searchable database and gives you a fuzzy-search popup for it. It works entirely offline, with no sync account or background service. It takes over Ctrl+R and the up-arrow key; if `ft.terminal`'s fzf integration is also on, fzf's own Ctrl+T/Alt+C shortcuts are unaffected because atuin loads after fzf and only touches those two bindings.
- [ft.cad3d](#ftcad3d) — Installs a 3D printing and CAD toolset for slicing and modeling: OrcaSlicer, Blender, FreeCAD, OpenSCAD, Inkscape, MeshLab, admesh, and f3d. OrcaSlicer's Creality K2 profiles cover Klipper-based slicing out of the box; the rest cover parametric/mesh modeling, vector art, and STL cleanup before slicing.
- [ft.cli](#ftcli) — Installs `just` and a small `ft` wrapper so you can run the framework's `ft` commands from any directory. This is the Home Manager equivalent of the NixOS `ft.cli` module, useful on its own for standalone Home Manager setups or non-NixOS distros like SteamOS or Bazzite. You need `ft.repoPath` set to your consumer repo's location for it to work.
- [ft.containers](#ftcontainers) — Sets up a container runtime — Docker or Podman — that runs entirely under your own user account, no root needed. Comes with the real Docker Compose v2 and, optionally, Distrobox. Other user-level apps such as `ft.komodo` build on top of this and connect to it through `ft.containers.socket`.
- [ft.core](#ftcore) — Turns on the required Home Manager foundation that every other module depends on: it sets `stateVersion`, the home directory, XDG base directories, generic-Linux compatibility, and allows unfree packages. This needs to stay enabled for the other home modules to work.
- [ft.dotfiles](#ftdotfiles) — Symlinks every file under `ft.dotfiles.path` into place, recursively. It uses out-of-store symlinks, so you can edit your dotfiles directly and see the changes immediately, without rebuilding.
- [ft.flatpak](#ftflatpak) — Registers the Flathub remote for this user's own Flatpak installs and lets you declare which Flatpak apps you want via `services.flatpak.packages` (from nix-flatpak). You can set that list in this user's base config or in any of their `profiles/<name>/` submodules — all the lists get merged together. The host machine also needs `ft.flatpak.enable` (the NixOS side) so the Flatpak service and desktop portal actually exist.
- [ft.gaming](#ftgaming) — Installs a set of gaming companion tools into your user profile: MangoHud, ProtonUp-Qt, SteamTinkerLaunch, Goverlay, Heroic, steam-tui, steamcmd, and steam-run. This mirrors the package set from the NixOS `ft.gaming` module and is handy on its own for gaming-focused distros that already ship Steam, like SteamOS or Bazzite. Steam itself, GameMode, and gamescope stay NixOS-only, since they need system-level privileges this module can't grant.
- [ft.gitWorkflow](#ftgitworkflow) — Sets up a conventional-commit workflow for git: installs `conform`, `convco`, and `lefthook`, then wires up global git hooks (via `core.hooksPath`) that check formatting with treefmt and scan for secrets with trufflehog before each commit, and enforce conventional commit message format when you write the message. It also appends NixOS generation info (written by the `ft` switch recipe) to your commit messages automatically, and gives you `convco`'s interactive commit builder.
- [ft.gitops](#ftgitops) — Runs a background service that keeps a standalone Home Manager profile in sync with a git repo: it clones and pulls `remote.url`, and whenever there's a new commit on `remote.branch`, it runs `home-manager switch` against `homeConfigurations.<flakeAttr>`. If a switch fails, it retries the same commit up to `retry.maxAttempts` times before giving up until a newer commit arrives. This is a from-scratch equivalent of the NixOS side's comin-based `ft.gitops`, built because comin has no concept of Home Manager.
- [ft.karousel](#ftkarousel) — Installs the Karousel scrollable-tiling script for KWin and turns it on through `kwinrc`. Requires `ft.plasmaManager.enable`, since that's what manages the `kwinrc` Plugins settings declaratively.
- [ft.komodo](#ftkomodo) — Deploys the upstream Komodo stack — Core, Periphery, and its FerretDB/Postgres database — as a docker-compose service running under your own user account, built on top of the Home Manager `ft.containers`. Requires `ft.containers.enable` with `compose.enable` turned on. Exempt from VM smoke tests, since it pulls container images from ghcr.io at runtime.
- [ft.lazyvim](#ftlazyvim) — Installs Neovim along with a full set of language servers and development tools for Python, Go, Rust, Nix, and web development. It symlinks `ft.dotfiles.path/nvim` into your XDG config as a live, editable link, and sets `EDITOR`/`VISUAL` to `nvim`.
- [ft.mullet](#ftmullet) — Lets you add or remove your own packages by editing a plain text file instead of touching Nix. Every package name listed in the file at `ft.mullet.sourcePath` gets installed for this user; names that don't resolve to a real package are just skipped. This is the Home Manager counterpart of the NixOS `ft.mullet` module.
- [ft.nixIndex](#ftnixindex) — Installs nix-index along with a ready-made database and the `comma` helper into your user profile, so you can look up which package provides a command. This is the Home Manager counterpart of the NixOS `ft.nixIndex` module, and is especially handy on standalone Home Manager systems or non-NixOS distros like SteamOS or Bazzite.
- [ft.noctalia](#ftnoctalia) — Installs and runs Noctalia, a QuickShell-based Wayland shell/bar, kept running as a systemd user service. Meant to run inside a niri session (ft.niri, NixOS). Requires ft.vicinae.enable, since Vicinae is the launcher used in place of Noctalia's own built-in one — bind niri's launcher keybind to `vicinae toggle` and disable Noctalia's built-in launcher panel through its own settings. Configure appearance and behavior directly through `programs.noctalia.{settings,customPalettes}`, which Noctalia's own module provides. For the supporting NixOS-level services (NetworkManager, Bluetooth, UPower, power profiles), also enable the host's `ft.noctalia.enable` (NixOS).
- [ft.plasmaManager](#ftplasmamanager) — Lets you set KDE Plasma preferences — panels, keyboard shortcuts, window-manager settings, and more — directly in your Home Manager config through `programs.plasma.*`, instead of clicking through Plasma's settings app.
- [ft.rclone](#ftrclone) — Automatically mounts a cloud storage remote (via rclone) as a folder under your home directory, kept running by a systemd user service. This pairs with the NixOS `ft.rclone` module, which installs rclone and FUSE system-wide; this module handles the actual per-user mount.
- [ft.repoPath](#ftrepopath) — The absolute path to your consumer flake repo's root directory. Set this in `homes/<username>/default.nix`.
- [ft.sops](#ftsops) — Sets up sops-nix for this user so secrets can be decrypted automatically — it points to the age key at `~/.config/sops/age/keys.txt` and to this user's secrets file at `var/secrets.yaml` in your consumer repo.
- [ft.steamConfig](#ftsteamconfig) — Lets you manage Steam's per-game settings declaratively — launch options, compatibility tool overrides, and shortcuts for non-Steam games — instead of clicking through Steam's own settings. Once enabled, configure individual games under `programs.steam.config.apps` and `programs.steam.config.nonSteamApps`. This is the Home Manager counterpart of the NixOS `ft.steamConfig` module, meant for standalone Home Manager systems or non-NixOS distros.
- [ft.terminal](#ftterminal) — Sets up a complete terminal environment: the `ghostty` terminal emulator, zsh configured from your dotfiles with plugins that load lazily, the starship prompt, `zoxide`, `fzf`, and a curated set of everyday CLI tools like `bat`, `eza`, `btop`, `fd`, `ripgrep`, `yazi`, `lazygit`, and `tealdeer`. The starship and ghostty config files are linked directly from your dotfiles, so edits take effect immediately.
- [ft.theme](#fttheme) — Applies one consistent look across your whole desktop using Stylix — a Catppuccin Mocha color scheme, matching fonts (Atkinson Hyperlegible, AtkynsonMono Nerd Font, and IBM Plex Serif), a matching cursor theme, window/terminal transparency, and your wallpaper. You can override any of these with `ft.theme.wallpaper`, `ft.theme.schemePath`, and `ft.theme.fonts.*`.
- [ft.vicinae](#ftvicinae) — Installs and runs Vicinae, a Raycast-compatible app launcher with app search, clipboard history, an emoji picker, a calculator, and support for Raycast extensions, kept running as a systemd user service. Configure it directly through `programs.vicinae.{extensions,themes,settings}`, which Vicinae's own module provides. For global hotkeys and keystroke injection, also enable the host's `ft.vicinae.inputServer.enable` (NixOS).
- [ft.webapps](#ftwebapps) — Creates application-launcher shortcuts that open any website in its own app-like window — no address bar or tabs — using a Chromium-family browser's `--app=` mode, each with its own isolated browser profile. A lightweight alternative to packaging a full Electron wrapper for every site.
- [ft.wine](#ftwine) — Installs Bottles, Wine (the WOW64 build), and Winetricks so you can run Windows applications outside of Steam. This is the Home Manager counterpart of the NixOS `ft.wine` module, meant for standalone Home Manager systems or non-NixOS distros.

---

## ft.atuin

Replaces zsh's plain history search with atuin, which stores your shell history in a searchable database and gives you a fuzzy-search popup for it. It works entirely offline, with no sync account or background service. It takes over Ctrl+R and the up-arrow key; if `ft.terminal`'s fzf integration is also on, fzf's own Ctrl+T/Alt+C shortcuts are unaffected because atuin loads after fzf and only touches those two bindings.

### ft.atuin.enable

Replaces zsh's plain history search with atuin, which stores your shell history in a searchable database and gives you a fuzzy-search popup for it. It works entirely offline, with no sync account or background service. It takes over Ctrl+R and the up-arrow key; if `ft.terminal`'s fzf integration is also on, fzf's own Ctrl+T/Alt+C shortcuts are unaffected because atuin loads after fzf and only touches those two bindings.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/atuin.nix](atuin.nix)

## ft.cad3d

Installs a 3D printing and CAD toolset for slicing and modeling: OrcaSlicer, Blender, FreeCAD, OpenSCAD, Inkscape, MeshLab, admesh, and f3d. OrcaSlicer's Creality K2 profiles cover Klipper-based slicing out of the box; the rest cover parametric/mesh modeling, vector art, and STL cleanup before slicing.

### ft.cad3d.enable

Installs a 3D printing and CAD toolset for slicing and modeling: OrcaSlicer, Blender, FreeCAD, OpenSCAD, Inkscape, MeshLab, admesh, and f3d. OrcaSlicer's Creality K2 profiles cover Klipper-based slicing out of the box; the rest cover parametric/mesh modeling, vector art, and STL cleanup before slicing.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/cad3d.nix](cad3d.nix)

## ft.cli

Installs `just` and a small `ft` wrapper so you can run the framework's `ft` commands from any directory. This is the Home Manager equivalent of the NixOS `ft.cli` module, useful on its own for standalone Home Manager setups or non-NixOS distros like SteamOS or Bazzite. You need `ft.repoPath` set to your consumer repo's location for it to work.

### ft.cli.enable

Installs `just` and a small `ft` wrapper so you can run the framework's `ft` commands from any directory. This is the Home Manager equivalent of the NixOS `ft.cli` module, useful on its own for standalone Home Manager setups or non-NixOS distros like SteamOS or Bazzite. You need `ft.repoPath` set to your consumer repo's location for it to work.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/cli.nix](cli.nix)

## ft.containers

Sets up a container runtime — Docker or Podman — that runs entirely under your own user account, no root needed. Comes with the real Docker Compose v2 and, optionally, Distrobox. Other user-level apps such as `ft.komodo` build on top of this and connect to it through `ft.containers.socket`.

### ft.containers.compose.enable

Installs the real Docker Compose v2 binary (`pkgs.docker-compose`) into your user profile. `podman-compose` is never used here.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/home/containers.nix](containers.nix)

### ft.containers.dataDir

The base directory where your docker-compose projects and bind-mounted data live.

*Type:*
string

*Default:*
`"/home/docs-eval/.local/share/containers"`

*Declared by:*
- [modules/home/containers.nix](containers.nix)

### ft.containers.distrobox.enable

Installs Distrobox into your user profile, so you can run containers based on other Linux distributions that feel integrated with your host system.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/home/containers.nix](containers.nix)

### ft.containers.enable

Sets up a container runtime — Docker or Podman — that runs entirely under your own user account, no root needed. Comes with the real Docker Compose v2 and, optionally, Distrobox. Other user-level apps such as `ft.komodo` build on top of this and connect to it through `ft.containers.socket`.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/containers.nix](containers.nix)

### ft.containers.runtime

Which container runtime to use. Podman runs natively as your own user through a systemd `--user` socket. Docker instead assumes you already have a rootless `dockerd` running for your user, set up outside Home Manager. Either way, the real `docker-compose` binary talks to it through a Docker-API-compatible socket.

*Type:*
one of "docker", "podman"

*Default:*
`"podman"`

*Declared by:*
- [modules/home/containers.nix](containers.nix)

### ft.containers.socket

Read-only. The Docker-API-compatible socket (in systemd's `%t` form) that the runtime exposes. Other user-level apps built on this module, such as `ft.komodo`, use this value as their `DOCKER_HOST`.

*Type:*
string

*Default:*
`"%t/podman/podman.sock"`

*Declared by:*
- [modules/home/containers.nix](containers.nix)

## ft.core

Turns on the required Home Manager foundation that every other module depends on: it sets `stateVersion`, the home directory, XDG base directories, generic-Linux compatibility, and allows unfree packages. This needs to stay enabled for the other home modules to work.

### ft.core.enable

Turns on the required Home Manager foundation that every other module depends on: it sets `stateVersion`, the home directory, XDG base directories, generic-Linux compatibility, and allows unfree packages. This needs to stay enabled for the other home modules to work.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/home/home-core.nix](home-core.nix)

### ft.core.genericLinux

Turns on Home Manager's `targets.genericLinux`, which loads its session variables into your shell profiles and sets up the per-user Nix profile path (`~/.local/state/nix/profiles/home-path`). You need this when running standalone Home Manager on a non-NixOS Linux distro (Ubuntu, Fedora, etc.). Leave it off when Home Manager is used as a NixOS module (`home-manager.nixosModules.home-manager`) — turning it on there fails, because `~/.local/state/nix/profiles` doesn't exist on a freshly-booted NixOS system.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/home-core.nix](home-core.nix)

### ft.core.stateVersion

The Home Manager release this user profile was originally created on. Home Manager uses this to decide which one-time state migrations to run, so getting it wrong can trigger changes you don't want. Set it once when the profile is created and leave it alone after that.

*Type:*
string

*Declared by:*
- [modules/home/home-core.nix](home-core.nix)

## ft.dotfiles

Symlinks every file under `ft.dotfiles.path` into place, recursively. It uses out-of-store symlinks, so you can edit your dotfiles directly and see the changes immediately, without rebuilding.

### ft.dotfiles.enable

Symlinks every file under `ft.dotfiles.path` into place, recursively. It uses out-of-store symlinks, so you can edit your dotfiles directly and see the changes immediately, without rebuilding.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/dotfiles.nix](dotfiles.nix)

### ft.dotfiles.path

The absolute path to this user's dotfiles directory.

*Type:*
string

*Default:*
`"/nix/ft-home/users/docs-eval/dotfiles"`

*Declared by:*
- [modules/home/home-core.nix](home-core.nix)

## ft.flatpak

Registers the Flathub remote for this user's own Flatpak installs and lets you declare which Flatpak apps you want via `services.flatpak.packages` (from nix-flatpak). You can set that list in this user's base config or in any of their `profiles/<name>/` submodules — all the lists get merged together. The host machine also needs `ft.flatpak.enable` (the NixOS side) so the Flatpak service and desktop portal actually exist.

### ft.flatpak.enable

Registers the Flathub remote for this user's own Flatpak installs and lets you declare which Flatpak apps you want via `services.flatpak.packages` (from nix-flatpak). You can set that list in this user's base config or in any of their `profiles/<name>/` submodules — all the lists get merged together. The host machine also needs `ft.flatpak.enable` (the NixOS side) so the Flatpak service and desktop portal actually exist.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/flatpak.nix](flatpak.nix)

## ft.gaming

Installs a set of gaming companion tools into your user profile: MangoHud, ProtonUp-Qt, SteamTinkerLaunch, Goverlay, Heroic, steam-tui, steamcmd, and steam-run. This mirrors the package set from the NixOS `ft.gaming` module and is handy on its own for gaming-focused distros that already ship Steam, like SteamOS or Bazzite. Steam itself, GameMode, and gamescope stay NixOS-only, since they need system-level privileges this module can't grant.

### ft.gaming.enable

Installs a set of gaming companion tools into your user profile: MangoHud, ProtonUp-Qt, SteamTinkerLaunch, Goverlay, Heroic, steam-tui, steamcmd, and steam-run. This mirrors the package set from the NixOS `ft.gaming` module and is handy on its own for gaming-focused distros that already ship Steam, like SteamOS or Bazzite. Steam itself, GameMode, and gamescope stay NixOS-only, since they need system-level privileges this module can't grant.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/gaming.nix](gaming.nix)

## ft.gitWorkflow

Sets up a conventional-commit workflow for git: installs `conform`, `convco`, and `lefthook`, then wires up global git hooks (via `core.hooksPath`) that check formatting with treefmt and scan for secrets with trufflehog before each commit, and enforce conventional commit message format when you write the message. It also appends NixOS generation info (written by the `ft` switch recipe) to your commit messages automatically, and gives you `convco`'s interactive commit builder.

### ft.gitWorkflow.enable

Sets up a conventional-commit workflow for git: installs `conform`, `convco`, and `lefthook`, then wires up global git hooks (via `core.hooksPath`) that check formatting with treefmt and scan for secrets with trufflehog before each commit, and enforce conventional commit message format when you write the message. It also appends NixOS generation info (written by the `ft` switch recipe) to your commit messages automatically, and gives you `convco`'s interactive commit builder.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/git-workflow.nix](git-workflow.nix)

### ft.gitWorkflow.types

The commit types allowed in conventional commit messages. The commit-msg hook rejects any commit whose type isn't on this list.

*Type:*
list of string

*Default:*
`[
  "feat"
  "fix"
  "chore"
  "refactor"
  "docs"
  "style"
  "test"
  "ci"
  "perf"
  "build"
  "revert"
]`

*Declared by:*
- [modules/home/git-workflow.nix](git-workflow.nix)

## ft.gitops

Runs a background service that keeps a standalone Home Manager profile in sync with a git repo: it clones and pulls `remote.url`, and whenever there's a new commit on `remote.branch`, it runs `home-manager switch` against `homeConfigurations.<flakeAttr>`. If a switch fails, it retries the same commit up to `retry.maxAttempts` times before giving up until a newer commit arrives. This is a from-scratch equivalent of the NixOS side's comin-based `ft.gitops`, built because comin has no concept of Home Manager.

### ft.gitops.enable

Runs a background service that keeps a standalone Home Manager profile in sync with a git repo: it clones and pulls `remote.url`, and whenever there's a new commit on `remote.branch`, it runs `home-manager switch` against `homeConfigurations.<flakeAttr>`. If a switch fails, it retries the same commit up to `retry.maxAttempts` times before giving up until a newer commit arrives. This is a from-scratch equivalent of the NixOS side's comin-based `ft.gitops`, built because comin has no concept of Home Manager.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

### ft.gitops.flakeAttr

Which `homeConfigurations.<flakeAttr>` entry to switch to, e.g. "alice@x86_64-linux".

*Type:*
string

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

### ft.gitops.pollPeriod

How often, in seconds, this service checks `remote.url` for new commits.

*Type:*
signed integer

*Default:*
`60`

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

### ft.gitops.remote.branch

The branch this service tracks and deploys.

*Type:*
string

*Default:*
`"main"`

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

### ft.gitops.remote.url

The git URL this service clones and pulls from.

*Type:*
string

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

### ft.gitops.repoPath

The local path this service clones the repository into. It's a private checkout used only by this service, separate from any NixOS `ft.repoPath`, since standalone Home Manager may be running on a non-NixOS host.

*Type:*
string

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

### ft.gitops.retry.maxAttempts

How many consecutive failed switch attempts on the same commit to allow before giving up on it until a new commit is pushed. Retries happen at the `pollPeriod` cadence.

*Type:*
signed integer

*Default:*
`3`

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

### ft.gitops.signingKeys

Armored GPG public key files. A commit only gets switched to if it's signed by one of these keys. Leaving this list empty turns off signature verification entirely, so any commit on `remote.branch` deploys unattended — only do that for testing.

*Type:*
list of absolute path

*Default:*
`[ ]`

*Declared by:*
- [modules/home/gitops.nix](gitops.nix)

## ft.karousel

Installs the Karousel scrollable-tiling script for KWin and turns it on through `kwinrc`. Requires `ft.plasmaManager.enable`, since that's what manages the `kwinrc` Plugins settings declaratively.

### ft.karousel.enable

Installs the Karousel scrollable-tiling script for KWin and turns it on through `kwinrc`. Requires `ft.plasmaManager.enable`, since that's what manages the `kwinrc` Plugins settings declaratively.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/karousel.nix](karousel.nix)

## ft.komodo

Deploys the upstream Komodo stack — Core, Periphery, and its FerretDB/Postgres database — as a docker-compose service running under your own user account, built on top of the Home Manager `ft.containers`. Requires `ft.containers.enable` with `compose.enable` turned on. Exempt from VM smoke tests, since it pulls container images from ghcr.io at runtime.

### ft.komodo.adminPassword

The default initial Komodo admin password. This is only used when `ft.komodo.sopsEnv.enable` is false, and gets written to the Nix store, so treat it as local-only. When `sopsEnv` is on, `KOMODO_INIT_ADMIN_PASSWORD` from the sops env-file takes over instead.

*Type:*
string

*Default:*
`"admin"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.adminUsername

The initial Komodo admin username created the first time it launches. Not a secret.

*Type:*
string

*Default:*
`"admin"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.autoApply.apiEnvSecret

The sops secret key holding an env-file with `KOMODO_API_KEY` and `KOMODO_API_SECRET` (create a Komodo API key once to get these). The auto-apply service declares and reads this secret to authenticate against Komodo's API.

*Type:*
string

*Default:*
`"komodo/api_env"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.autoApply.enable

Once Komodo Core is up and responding, automatically runs the bundled `komodo-apply` recipe from `ft.repoPath` to bring Komodo in line with the consumer repo's `containers/` directory, entirely through Komodo's API with no UI involved. This runs as a one-shot user systemd service. Requires `ft.cli`, `ft.sops`, and `ft.repoPath`, plus a sops secret (`autoApply.apiEnvSecret`) holding `KOMODO_API_KEY` and `KOMODO_API_SECRET`. Exempt from VM smoke tests, since it reconciles against a live Komodo API. See NOTES.md.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.backupsPath

The path where Komodo Core writes its backup archives. This is bind-mounted into the Core container at `/backups`.

*Type:*
string

*Default:*
`"/home/docs-eval/.local/share/komodo/backups"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.dataDir

The base directory for the Komodo compose project — its compose files, credentials env-file, logs — and the default location for backups and Periphery's data.

*Type:*
string

*Default:*
`"/home/docs-eval/.local/share/komodo"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.dbPassword

The default password for the FerretDB/Postgres database. This is only used when `ft.komodo.sopsEnv.enable` is false, and gets written to the Nix store, so treat it as local-only. When `sopsEnv` is on, `KOMODO_DATABASE_PASSWORD` from the sops env-file takes over instead.

*Type:*
string

*Default:*
`"komodo"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.dbUsername

The username for the FerretDB/Postgres database. This isn't a secret — it's baked directly into the compose config.

*Type:*
string

*Default:*
`"komodo"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.enable

Deploys the upstream Komodo stack — Core, Periphery, and its FerretDB/Postgres database — as a docker-compose service running under your own user account, built on top of the Home Manager `ft.containers`. Requires `ft.containers.enable` with `compose.enable` turned on. Exempt from VM smoke tests, since it pulls container images from ghcr.io at runtime.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.host

The externally reachable URL for this Komodo Core instance, used for OAuth redirect URLs and suggested webhook addresses.

*Type:*
string

*Default:*
`"http://localhost:9120"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.imageTag

The image tag to use for the `ghcr.io/moghtech/komodo-core` and `komodo-periphery` images.

*Type:*
string

*Default:*
`"latest"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.includeDiskMounts

Which mount points Periphery should report disk usage for in the Komodo UI (`PERIPHERY_INCLUDE_DISK_MOUNTS`). Leave this empty to have Periphery report on every mount it detects.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.jwtSecret

The default secret used to sign Komodo JWT tokens. This is only used when `ft.komodo.sopsEnv.enable` is false, and gets written to the Nix store. When `sopsEnv` is on, `KOMODO_JWT_SECRET` from the sops env-file takes over instead.

*Type:*
string

*Default:*
`"komodo-jwt-secret"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.peripheryRootDirectory

Periphery's root directory (`PERIPHERY_ROOT_DIRECTORY`), bind-mounted into the periphery container at the same path. Every stack Periphery deploys, and the host side of every bind mount it manages, lives under this directory.

*Type:*
string

*Default:*
`"/home/docs-eval/.local/share/komodo/periphery"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.repoCachePath

A path bind-mounted into Komodo Core at `/repo-cache`, where it clones git repos for repo-based Stacks and Resource Syncs. Leave this `null` to keep those clones on the container's ephemeral layer instead.

*Type:*
null or string

*Default:*
`null`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.secrets.core.enable

Declares the `komodo/core_secrets` sops key, mounts it read-only into the Core container, and loads it with `core --config-path`. The values inside become usable as `[[KEY]]` placeholders in every Stack and Deployment. This is for values you want interpolated into deployed Stacks — it's separate from `ft.komodo.sopsEnv`, which covers Komodo's own login credentials instead. Needs sops-nix configured (usually via `ft.sops.enable`).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.secrets.periphery.enable

Declares the `komodo/periphery_secrets` sops key, mounts it read-only into the Periphery container, and loads it with `periphery --config-path`. The values inside become usable as `[[KEY]]` placeholders in the Stacks this Periphery deploys, and are kept out of the Komodo UI and logs. This is for values you want interpolated into deployed Stacks — it's separate from `ft.komodo.sopsEnv`, which covers Komodo's own login credentials instead. Needs sops-nix configured (usually via `ft.sops.enable`).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.serverName

The name for the first Komodo server entry, which Periphery also uses to identify itself when connecting to Core.

*Type:*
string

*Default:*
`"Local"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.sopsEnv.enable

Pulls the sensitive Komodo credentials (`KOMODO_DATABASE_PASSWORD`, `KOMODO_INIT_ADMIN_PASSWORD`, `KOMODO_JWT_SECRET`, `KOMODO_WEBHOOK_SECRET`) from a sops-decrypted env-file (`ft.komodo.sopsEnv.secretName`) instead of leaving the defaults in the Nix store. Needs sops-nix configured (usually via `ft.sops.enable`); populate the secret as `KEY=VALUE` lines — see NOTES.md.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.sopsEnv.secretName

The sops secret key that holds the Komodo credentials as an env-file (`KEY=VALUE` lines). This gets declared and decrypted whenever `sopsEnv.enable` is true.

*Type:*
string

*Default:*
`"komodo/env"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.syncPath

A path bind-mounted into Komodo Core at `/syncs`, used for 'Files on Server' Resource Syncs. Leave this `null` to keep those files on the container's ephemeral layer instead.

*Type:*
null or string

*Default:*
`null`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.timezone

The timezone Komodo uses for its schedules, as a tz database name (e.g. `America/New_York`).

*Type:*
string

*Default:*
`"Etc/UTC"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

### ft.komodo.webhookSecret

The default secret used to authenticate incoming Komodo webhooks. This is only used when `ft.komodo.sopsEnv.enable` is false, and gets written to the Nix store. When `sopsEnv` is on, `KOMODO_WEBHOOK_SECRET` from the sops env-file takes over instead.

*Type:*
string

*Default:*
`"komodo-webhook-secret"`

*Declared by:*
- [modules/home/komodo.nix](komodo.nix)

## ft.lazyvim

Installs Neovim along with a full set of language servers and development tools for Python, Go, Rust, Nix, and web development. It symlinks `ft.dotfiles.path/nvim` into your XDG config as a live, editable link, and sets `EDITOR`/`VISUAL` to `nvim`.

### ft.lazyvim.enable

Installs Neovim along with a full set of language servers and development tools for Python, Go, Rust, Nix, and web development. It symlinks `ft.dotfiles.path/nvim` into your XDG config as a live, editable link, and sets `EDITOR`/`VISUAL` to `nvim`.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/lazyvim.nix](lazyvim.nix)

## ft.mullet

Lets you add or remove your own packages by editing a plain text file instead of touching Nix. Every package name listed in the file at `ft.mullet.sourcePath` gets installed for this user; names that don't resolve to a real package are just skipped. This is the Home Manager counterpart of the NixOS `ft.mullet` module.

### ft.mullet.enable

Lets you add or remove your own packages by editing a plain text file instead of touching Nix. Every package name listed in the file at `ft.mullet.sourcePath` gets installed for this user; names that don't resolve to a real package are just skipped. This is the Home Manager counterpart of the NixOS `ft.mullet` module.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/mullet.nix](mullet.nix)

### ft.mullet.sourcePath

Path to the plain text file listing this user's package names, one per line. When this configuration comes from `ft-home.lib.mkFlake`, it defaults to `var/mullet.txt` inside this user's own `users/<username>/` directory. Set it yourself to use a different location, or if you're using this module outside the generator where no default is available.

*Type:*
null or absolute path

*Default:*
`null`

*Example:*
`./var/mullet-custom.txt`

*Declared by:*
- [modules/home/mullet.nix](mullet.nix)

## ft.nixIndex

Installs nix-index along with a ready-made database and the `comma` helper into your user profile, so you can look up which package provides a command. This is the Home Manager counterpart of the NixOS `ft.nixIndex` module, and is especially handy on standalone Home Manager systems or non-NixOS distros like SteamOS or Bazzite.

### ft.nixIndex.comma

Lets you run a command you haven't installed yet — `comma` looks it up via nix-index and runs it for you.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/home/nix-index.nix](nix-index.nix)

### ft.nixIndex.enable

Installs nix-index along with a ready-made database and the `comma` helper into your user profile, so you can look up which package provides a command. This is the Home Manager counterpart of the NixOS `ft.nixIndex` module, and is especially handy on standalone Home Manager systems or non-NixOS distros like SteamOS or Bazzite.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/home/nix-index.nix](nix-index.nix)

## ft.noctalia

Installs and runs Noctalia, a QuickShell-based Wayland shell/bar, kept running as a systemd user service. Meant to run inside a niri session (ft.niri, NixOS). Requires ft.vicinae.enable, since Vicinae is the launcher used in place of Noctalia's own built-in one — bind niri's launcher keybind to `vicinae toggle` and disable Noctalia's built-in launcher panel through its own settings. Configure appearance and behavior directly through `programs.noctalia.{settings,customPalettes}`, which Noctalia's own module provides. For the supporting NixOS-level services (NetworkManager, Bluetooth, UPower, power profiles), also enable the host's `ft.noctalia.enable` (NixOS).

### ft.noctalia.enable

Installs and runs Noctalia, a QuickShell-based Wayland shell/bar, kept running as a systemd user service. Meant to run inside a niri session (ft.niri, NixOS). Requires ft.vicinae.enable, since Vicinae is the launcher used in place of Noctalia's own built-in one — bind niri's launcher keybind to `vicinae toggle` and disable Noctalia's built-in launcher panel through its own settings. Configure appearance and behavior directly through `programs.noctalia.{settings,customPalettes}`, which Noctalia's own module provides. For the supporting NixOS-level services (NetworkManager, Bluetooth, UPower, power profiles), also enable the host's `ft.noctalia.enable` (NixOS).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/noctalia.nix](noctalia.nix)

## ft.plasmaManager

Lets you set KDE Plasma preferences — panels, keyboard shortcuts, window-manager settings, and more — directly in your Home Manager config through `programs.plasma.*`, instead of clicking through Plasma's settings app.

### ft.plasmaManager.enable

Lets you set KDE Plasma preferences — panels, keyboard shortcuts, window-manager settings, and more — directly in your Home Manager config through `programs.plasma.*`, instead of clicking through Plasma's settings app.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/plasma-manager.nix](plasma-manager.nix)

## ft.rclone

Automatically mounts a cloud storage remote (via rclone) as a folder under your home directory, kept running by a systemd user service. This pairs with the NixOS `ft.rclone` module, which installs rclone and FUSE system-wide; this module handles the actual per-user mount.

### ft.rclone.enable

Automatically mounts a cloud storage remote (via rclone) as a folder under your home directory, kept running by a systemd user service. This pairs with the NixOS `ft.rclone` module, which installs rclone and FUSE system-wide; this module handles the actual per-user mount.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/rclone.nix](rclone.nix)

### ft.rclone.extraMountArgs

Extra command-line arguments passed to `rclone mount`, added after the remote and mount-point arguments — useful for things like cache mode or buffer size.

*Type:*
list of string

*Default:*
`[
  "--vfs-cache-mode"
  "writes"
]`

*Declared by:*
- [modules/home/rclone.nix](rclone.nix)

### ft.rclone.mountPoint

Name of the folder under your home directory where the remote gets mounted, e.g. `~/GoogleDrive`.

*Type:*
string

*Default:*
`"GoogleDrive"`

*Example:*
`"GoogleDrive"`

*Declared by:*
- [modules/home/rclone.nix](rclone.nix)

### ft.rclone.remoteName

Name of the rclone remote to mount, as set up in your rclone config (e.g. with `rclone config`). This must match a remote that already exists.

*Type:*
string

*Default:*
`"gdrive"`

*Example:*
`"gdrive"`

*Declared by:*
- [modules/home/rclone.nix](rclone.nix)

## ft.repoPath

The absolute path to your consumer flake repo's root directory. Set this in `homes/<username>/default.nix`.

*Type:*
string

*Default:*
`"/nix/ft-home"`

*Declared by:*
- [modules/home/home-core.nix](home-core.nix)

## ft.sops

Sets up sops-nix for this user so secrets can be decrypted automatically — it points to the age key at `~/.config/sops/age/keys.txt` and to this user's secrets file at `var/secrets.yaml` in your consumer repo.

### ft.sops.enable

Sets up sops-nix for this user so secrets can be decrypted automatically — it points to the age key at `~/.config/sops/age/keys.txt` and to this user's secrets file at `var/secrets.yaml` in your consumer repo.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/sops.nix](sops.nix)

## ft.steamConfig

Lets you manage Steam's per-game settings declaratively — launch options, compatibility tool overrides, and shortcuts for non-Steam games — instead of clicking through Steam's own settings. Once enabled, configure individual games under `programs.steam.config.apps` and `programs.steam.config.nonSteamApps`. This is the Home Manager counterpart of the NixOS `ft.steamConfig` module, meant for standalone Home Manager systems or non-NixOS distros.

### ft.steamConfig.enable

Lets you manage Steam's per-game settings declaratively — launch options, compatibility tool overrides, and shortcuts for non-Steam games — instead of clicking through Steam's own settings. Once enabled, configure individual games under `programs.steam.config.apps` and `programs.steam.config.nonSteamApps`. This is the Home Manager counterpart of the NixOS `ft.steamConfig` module, meant for standalone Home Manager systems or non-NixOS distros.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/steam-config.nix](steam-config.nix)

## ft.terminal

Sets up a complete terminal environment: the `ghostty` terminal emulator, zsh configured from your dotfiles with plugins that load lazily, the starship prompt, `zoxide`, `fzf`, and a curated set of everyday CLI tools like `bat`, `eza`, `btop`, `fd`, `ripgrep`, `yazi`, `lazygit`, and `tealdeer`. The starship and ghostty config files are linked directly from your dotfiles, so edits take effect immediately.

### ft.terminal.enable

Sets up a complete terminal environment: the `ghostty` terminal emulator, zsh configured from your dotfiles with plugins that load lazily, the starship prompt, `zoxide`, `fzf`, and a curated set of everyday CLI tools like `bat`, `eza`, `btop`, `fd`, `ripgrep`, `yazi`, `lazygit`, and `tealdeer`. The starship and ghostty config files are linked directly from your dotfiles, so edits take effect immediately.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/home/terminal.nix](terminal.nix)

### ft.terminal.zshPlugins.autosuggestions.enable

Suggests commands as you type, based on your shell history. Loaded lazily via zsh-defer so it doesn't slow down shell startup.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/home/terminal.nix](terminal.nix)

### ft.terminal.zshPlugins.commaAssistant.enable

Makes 'command not found' errors friendlier by offering to run the missing command via `comma`, and — when `zshPlugins.syntaxHighlighting` is also on — highlights commands that are available through comma/nix-index. Needs `ft.nixIndex.enable` for the `comma` binary and its database; does nothing if that's off. Loaded lazily via zsh-defer so it doesn't slow down shell startup. Note: this currently defaults to off because the pinned source still uses a placeholder hash instead of a real one.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/home/terminal.nix](terminal.nix)

### ft.terminal.zshPlugins.completions.enable

Adds a larger collection of tab-completion definitions for zsh.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/home/terminal.nix](terminal.nix)

### ft.terminal.zshPlugins.syntaxHighlighting.enable

Highlights commands in your shell as you type them. Loaded lazily via zsh-defer so it doesn't slow down shell startup.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/home/terminal.nix](terminal.nix)

## ft.theme

Applies one consistent look across your whole desktop using Stylix — a Catppuccin Mocha color scheme, matching fonts (Atkinson Hyperlegible, AtkynsonMono Nerd Font, and IBM Plex Serif), a matching cursor theme, window/terminal transparency, and your wallpaper. You can override any of these with `ft.theme.wallpaper`, `ft.theme.schemePath`, and `ft.theme.fonts.*`.

### ft.theme.enable

Applies one consistent look across your whole desktop using Stylix — a Catppuccin Mocha color scheme, matching fonts (Atkinson Hyperlegible, AtkynsonMono Nerd Font, and IBM Plex Serif), a matching cursor theme, window/terminal transparency, and your wallpaper. You can override any of these with `ft.theme.wallpaper`, `ft.theme.schemePath`, and `ft.theme.fonts.*`.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.emoji.name

Name of the font family used to render emoji.

*Type:*
string

*Default:*
`"Noto Color Emoji"`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.emoji.package

The package that provides the emoji font.

*Type:*
package

*Default:*
`<derivation noto-fonts-color-emoji-2.051>`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.mono.name

Name of the font family used for monospace text, such as in the terminal.

*Type:*
string

*Default:*
`"AtkynsonMono Nerd Font Mono"`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.mono.package

The package that provides the monospace font.

*Type:*
package

*Default:*
`<derivation nerd-fonts-atkynson-mono-3.4.0+2.001>`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.sans.name

Name of the font family used for sans-serif text.

*Type:*
string

*Default:*
`"Atkinson Hyperlegible"`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.sans.package

The package that provides the sans-serif font.

*Type:*
package

*Default:*
`<derivation atkinson-hyperlegible-0-unstable-2021-04-29>`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.serif.name

Name of the font family used for serif text.

*Type:*
string

*Default:*
`"IBM Plex Serif"`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.fonts.serif.package

The package that provides the serif font.

*Type:*
package

*Default:*
`<derivation ibm-plex-0-unstable-2026-05-26>`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.schemeName

The scheme's display name, shown wherever the theme's name is referenced.

*Type:*
string

*Default:*
`"Catppuccin Mocha"`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.schemePath

Path to the color scheme file (in Base16 YAML format) used to theme everything.

*Type:*
absolute path or string

*Default:*
`"/nix/store/6b8y0g0vyz2lh84rn4mscvhlwzgga6ql-base16-schemes-0-unstable-2026-01-15/share/themes/catppuccin-mocha.yaml"`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

### ft.theme.wallpaper

Path to your desktop wallpaper — required, since there's no sensible default. Set it in your own config, e.g. `ft.theme.wallpaper = ./wallpapers/default.png;`. The framework can't supply a default itself because a path there would point into the framework's own repo rather than yours.

*Type:*
absolute path or string

*Example:*
`./wallpapers/default.png`

*Declared by:*
- [modules/home/stylix.nix](stylix.nix)

## ft.vicinae

Installs and runs Vicinae, a Raycast-compatible app launcher with app search, clipboard history, an emoji picker, a calculator, and support for Raycast extensions, kept running as a systemd user service. Configure it directly through `programs.vicinae.{extensions,themes,settings}`, which Vicinae's own module provides. For global hotkeys and keystroke injection, also enable the host's `ft.vicinae.inputServer.enable` (NixOS).

### ft.vicinae.enable

Installs and runs Vicinae, a Raycast-compatible app launcher with app search, clipboard history, an emoji picker, a calculator, and support for Raycast extensions, kept running as a systemd user service. Configure it directly through `programs.vicinae.{extensions,themes,settings}`, which Vicinae's own module provides. For global hotkeys and keystroke injection, also enable the host's `ft.vicinae.inputServer.enable` (NixOS).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/vicinae.nix](vicinae.nix)

## ft.webapps

Creates application-launcher shortcuts that open any website in its own app-like window — no address bar or tabs — using a Chromium-family browser's `--app=` mode, each with its own isolated browser profile. A lightweight alternative to packaging a full Electron wrapper for every site.

### ft.webapps.apps

The set of websites to expose as desktop launchers, keyed by a short id used for the app's isolated profile folder and window class.

*Type:*
attribute set of (submodule)

*Default:*
`{ }`

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

### ft.webapps.apps.<name>.browser

Overrides which browser launches this particular webapp. Leave unset to use `ft.webapps.browser`.

*Type:*
null or one of "chromium", "google-chrome", "brave", "vivaldi", "ungoogled-chromium"

*Default:*
`null`

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

### ft.webapps.apps.<name>.categories

Desktop-entry categories that control where this webapp shows up in application menus.

*Type:*
list of string

*Default:*
`[
  "Network"
]`

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

### ft.webapps.apps.<name>.icon

Path to a local icon image to use. If left unset, the site's favicon is fetched automatically when Home Manager activates; if that fetch fails (e.g. no internet), it just falls back to the browser's default icon.

*Type:*
null or absolute path

*Default:*
`null`

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

### ft.webapps.apps.<name>.name

The name shown for this webapp in your application launcher.

*Type:*
string

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

### ft.webapps.apps.<name>.url

The URL this webapp's window opens to.

*Type:*
string

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

### ft.webapps.browser

Which Chromium-family browser to use for launching webapps in `--app=` mode. Only Chromium-family browsers support this; Firefox isn't offered here since it needs the separate PWAsForFirefox setup to do something similar.

*Type:*
one of "chromium", "google-chrome", "brave", "vivaldi", "ungoogled-chromium"

*Default:*
`"chromium"`

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

### ft.webapps.enable

Creates application-launcher shortcuts that open any website in its own app-like window — no address bar or tabs — using a Chromium-family browser's `--app=` mode, each with its own isolated browser profile. A lightweight alternative to packaging a full Electron wrapper for every site.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/webapps.nix](webapps.nix)

## ft.wine

Installs Bottles, Wine (the WOW64 build), and Winetricks so you can run Windows applications outside of Steam. This is the Home Manager counterpart of the NixOS `ft.wine` module, meant for standalone Home Manager systems or non-NixOS distros.

### ft.wine.enable

Installs Bottles, Wine (the WOW64 build), and Winetricks so you can run Windows applications outside of Steam. This is the Home Manager counterpart of the NixOS `ft.wine` module, meant for standalone Home Manager systems or non-NixOS distros.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/home/wine.nix](wine.nix)

