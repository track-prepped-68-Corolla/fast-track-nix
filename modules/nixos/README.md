# Module Options

## Table of Contents

- [ft.admin](#ftadmin) — Sets up a dedicated admin account with sudo access, present on every machine by default (you can turn it off). It can log in with an SSH key via `authorizedKeys`, a password via `initialPassword`, or both, so you're never locked out. This account is kept separate from `ft.users` so there's always one predictable place that owns the admin user.
- [ft.bulkPool](#ftbulkpool) — Sets up a pooled bulk storage array: reads machines/<host>/var/bulk-drives.nix for the drives you've registered (labelled bulk-*), mounts each one, combines the data and cache drives into a single pool with mergerfs, and protects the data drives with nightly SnapRAID parity syncs. Does nothing when drivesFile is unset or every drive list is empty.
- [ft.cachyos](#ftcachyos) — Swaps the default kernel for a CachyOS build tuned for performance, pulled from the nix-cachyos flake input. Pick which build with `ft.cachyos.variant` (default: latest) — variants ending in `-x86_64-v3`, `-x86_64-v4`, or `-zen4` are tuned for specific CPU generations, and variants ending in `-lto` are compiled with link-time optimisation.
- [ft.cardwire](#ftcardwire) — Turns on the cardwired service, which can block or unblock GPU device nodes so you can switch between integrated, hybrid, or manual GPU power modes. It works by hooking into the kernel with eBPF, so it needs a kernel built with `CONFIG_BPF_LSM=y` and `lsm=...,bpf` added to the boot parameters.
- [ft.cli](#ftcli) — Installs `just` along with a small `ft` command that runs the framework's built-in recipes from anywhere on the system. It's on by default since almost every machine wants it. It needs `ft.repoPath` set to your consumer repo's location — turn this off for machines that don't have a real checkout of your repo, like a live ISO or a test-only build.
- [ft.containers](#ftcontainers) — Sets up a container runtime — Docker or Podman, running as root or rootless — along with the real Docker Compose v2 binary and, optionally, Distrobox. Other features, like ft.komodo, build on top of this and reach the daemon through the Docker-API-compatible socket this module provides.
- [ft.core](#ftcore) — The baseline every machine starts from: network management, Bluetooth, network printing, zsh as the shell, and a set of everyday CLI tools. Every value here is just a default, so any host can override individual pieces.
- [ft.cosmic](#ftcosmic) — Turns on the COSMIC desktop environment along with system76-scheduler, which prioritizes process scheduling for better responsiveness, and makes sure graphics hardware acceleration is on. Pair it with `ft.cosmicGreeter` to use cosmic-greeter as the login screen, or set up a different display manager to launch the COSMIC session instead.
- [ft.cosmicGreeter](#ftcosmicgreeter) — Turns on cosmic-greeter as the login screen. Pair it with `ft.cosmic` to boot straight into a COSMIC session.
- [ft.deploy](#ftdeploy) — Adds this machine to the fleet that can be deployed remotely with `colmena apply`. It's off by default, so you opt each machine in individually — that way local-only machines or disk images never accidentally become a remote deploy target.
- [ft.diskBtrfs](#ftdiskbtrfs) — Sets up disk partitioning for a machine: a small 1 GiB boot partition (ESP) and a btrfs root split into subvolumes for `/home`, `/nix` (with copy-on-write turned off), `/src`, and `/.snapshots`, all using zstd compression. You can optionally wrap the btrfs partition in LUKS2 encryption. When `impermanence.enable` is on, the root subvolume becomes a tmpfs ramdisk that's wiped on every boot, with a separate `@persist` subvolume added at `/persist` to hold the state that should survive. `/src` is set up so members of the `wheel` group can write to it without `sudo` — it's owned `root:wheel` with permissions `2775` and a default ACL that grants group-write on everything created inside it, plus a repair pass at boot that fixes older files created before the ACL existed. Git's global `safe.directory` protection is also turned off system-wide, because every repository under `/src` gets placed there as root by `nixos-anywhere` during provisioning.
- [ft.facter](#ftfacter) — Uses a hardware report to detect and configure kernel modules automatically, instead of a hand-written `hardware-configuration.nix`. Generate the report on the target machine by running `nixos-facter`, commit it to `machines/<name>/var/facter.json`, and point `ft.facter.reportPath` at it (e.g. `./var/facter.json`) from the machine's `default.nix`.
- [ft.flatpak](#ftflatpak) — Turns on the system Flatpak service and adds the Flathub remote. Once enabled, `services.flatpak.packages` (provided by nix-flatpak) becomes the place to declare system-wide Flatpak apps — set it in any machine file, profile, or other module, and every definition merges together automatically. Pair this with `ft.flatpak.frontend.enable` to also get a graphical Flathub browser.
- [ft.gaming](#ftgaming) — Sets up the Steam gaming stack: Steam itself plus GameMode, gamescope, MangoHud, Proton-GE, and a curated set of launchers and tools. Turn on ft.gaming.bigPicture to have Steam boot straight into Big Picture mode using a gamescope session.
- [ft.gitops](#ftgitops) — Runs comin, a daemon that watches your git remotes and automatically deploys this machine's own configuration whenever new commits land: pushes to `deployBranch` are applied permanently with `switch`, while comin's per-host `testing-<hostname>` branch is applied only temporarily with `test` (a reboot reverts it). You can list multiple remotes and comin polls all of them, so no single remote being down stops deployments.
- [ft.gpu](#ftgpu) — Sets up graphics drivers for NVIDIA, AMD, or Intel GPUs. It can automatically detect which vendor you have and configure PRIME offloading for hybrid (Optimus) laptops with both an integrated and a discrete GPU.
- [ft.keepass](#ftkeepass) — Installs KeePassXC and turns off the GNOME Keyring so KeePassXC is the only place secrets are stored. This matters on desktops that mix components from different environments, where GNOME Keyring's auto-unlock could otherwise bypass your hardware key authentication.
- [ft.komodo](#ftkomodo) — Deploys Komodo's standard stack (Core, Periphery, and the FerretDB/Postgres database) using docker-compose, on top of ft.containers. Requires ft.containers.enable with compose.enable turned on. Exempt from VM smoke tests, since it pulls container images from ghcr.io at runtime.
- [ft.limine](#ftlimine) — Switches the boot loader to Limine and turns off systemd-boot, since having both active at once can leave the boot loader state in a confused mess.
- [ft.liveIso](#ftliveiso) — Builds a NixOS live environment with everything needed to set up a new machine, using nixos-anywhere, disko, and nixos-facter. To produce an ISO, add a var/format marker file to the machine's directory (see flake-parts/lib/machines.nix) — the generator then emits it as packages.<system>.<name> instead of a nixosConfiguration. Add SSH keys via ft.liveIso.authorizedKeys in the machine's default.nix.
- [ft.microvms](#ftmicrovms)
- [ft.moonlight](#ftmoonlight) — Runs a Moonlight-compatible stream host (Sunshine) for remote desktop use and low-latency game streaming, opening the necessary firewall ports by default. Clients connect using Moonlight or Artemis. Anyone streaming from this machine also needs to be a member of the `input` group for virtual-input emulation (gamepad/keyboard/mouse) to work.
- [ft.mullet](#ftmullet) — Installs every package listed in the plain text file at `ft.mullet.sourcePath`, one package name per line. This lets you add or remove packages by editing a text file instead of touching Nix code. Any name that doesn't resolve to a real package is just skipped.
- [ft.nfs](#ftnfs) — Sets up NFS client mounts declared under `ft.nfs.mounts`. Each entry gives a `remotePath` (e.g. server:/share) and a `mountPoint`, and is mounted on demand — with a 10-minute idle timeout — via systemd's automount.
- [ft.nixIndex](#ftnixindex) — Whether to enable nix-index with pre-built database and comma integration.
- [ft.plasma](#ftplasma) — Turns on KDE Plasma 6 with SDDM as the login screen and the X server enabled, along with KDE Connect for pairing with phones and other devices, KWallet for storing credentials, and a curated set of KDE apps (Kate, KCalc, Spectacle, Partition Manager, and KRDC). The Elisa music player is left out by default.
- [ft.plasmaBigscreen](#ftplasmabigscreen) — Installs Plasma Bigscreen, a TV-friendly interface, and registers its Wayland session so it can be selected as a login option. This module is exempt from the VM smoke test requirement, since it pulls in `qtwebengine` and the full KDE Frameworks stack (which depend on the binary cache) and its main input method, HDMI-CEC, can't be tested inside a VM (it depends on real hardware).
- [ft.printing](#ftprinting) — Starts CUPS along with a virtual PDF printer (CUPS-PDF) and Avahi for finding network printers via mDNS/Bonjour. Turn either piece off with `enableVirtualPdfPrinter` or `enableNetworkDiscovery`, and add hardware drivers via `extraDrivers`.
- [ft.rclone](#ftrclone) — Installs rclone and FUSE for the whole system and allows FUSE mounts to be shared with other users, so a per-user rclone mount service can expose a cloud drive (like Google Drive) at the configured mount point.
- [ft.repoPath](#ftrepopath) — Absolute path to your consumer repo on disk. Set this in your machine's config file.
- [ft.sops](#ftsops) — Sets up encrypted secrets management, pointing sops-nix at `ft.repoPath/var/secrets/secrets.yaml` and decrypting with the machine's SSH host key. Turn on `ft.sops.useTPM` or `ft.sops.useYubikey` instead if you'd rather decrypt with a hardware token.
- [ft.steamConfig](#ftsteamconfig) — Turns on steam-config-nix, which lets you declare Steam launch options, per-game compatibility-tool choices, and shortcuts for non-Steam games in your configuration instead of clicking through Steam's UI. Once enabled, configure individual games under programs.steam.config.apps and programs.steam.config.nonSteamApps.
- [ft.tailscale](#fttailscale) — Joins the machine to a Tailscale mesh network, trusts the tailscale0 interface in the firewall, and installs the Trayscale tray app. Set `ft.tailscale.useRoutingFeatures = "server"` to run this machine as an exit node.
- [ft.users](#ftusers) — Creates sudo users from `superUsers` and regular unprivileged users from `normalUsers`; everyone gets zsh as their shell and membership in the common hardware/service groups. The dedicated admin account is handled separately by the `ft.admin` module.
- [ft.vendorHw](#ftvendorhw) — Installs and configures the right drivers, background services, and tools for whichever hardware brand is detected in the hardware report. Covers Lenovo Legion, Razer, MSI, Logitech, Corsair, OpenRGB, ASUS ROG/TUF, and handheld gaming devices.
- [ft.vicinae](#ftvicinae) — Registers the upstream vicinae.cachix.org binary cache, so the Vicinae launcher (ft.vicinae.enable in Home Manager) doesn't have to compile its Qt6/C++ stack from source.
- [ft.virt](#ftvirt) — Sets up virtual machine support with libvirt/KVM and virt-manager, and adds `ft.users.mainUser` to the libvirtd group so they can manage VMs. You can also turn on `ft.virt.enableVmwareHost` for VMware Workstation, `ft.virt.enableIncus` for Incus containers, and `ft.virt.enableSpiceUsbRedirection` to pass USB devices through to VMs.
- [ft.wine](#ftwine) — Installs Bottles, Wine (the WOW64 build), and Winetricks so you can run Windows applications outside of Steam.
- [ft.yubikey](#ftyubikey) — Installs YubiKey management tools (`yubikey-manager`, `yubico-piv-tool`, `pam_u2f`), turns on the `pcscd` smart-card service, and activates `ft.users.u2f` so YubiKeys can be used for login. Set each user's FIDO2 credentials with `ft.users.u2f.mappings` in your machine config.

---

## ft.admin

Sets up a dedicated admin account with sudo access, present on every machine by default (you can turn it off). It can log in with an SSH key via `authorizedKeys`, a password via `initialPassword`, or both, so you're never locked out. This account is kept separate from `ft.users` so there's always one predictable place that owns the admin user.

### ft.admin.authorizedKeys

The SSH public keys allowed to log in as the admin user.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/system/admin.nix](system/admin.nix)

### ft.admin.enable

Sets up a dedicated admin account with sudo access, present on every machine by default (you can turn it off). It can log in with an SSH key via `authorizedKeys`, a password via `initialPassword`, or both, so you're never locked out. This account is kept separate from `ft.users` so there's always one predictable place that owns the admin user.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/admin.nix](system/admin.nix)

### ft.admin.extraGroups

Any extra groups to add the admin user to, beyond wheel and the standard hardware/service groups it already gets.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/system/admin.nix](system/admin.nix)

### ft.admin.hashedPasswordFile

Path to a file holding the admin's already-hashed password, such as a sops secret. When set, it takes priority over `initialPassword`.

*Type:*
null or absolute path

*Default:*
`null`

*Declared by:*
- [modules/nixos/system/admin.nix](system/admin.nix)

### ft.admin.initialPassword

A plain-text password set the first time the machine boots, so the account is never locked out. Override it per machine, set it to null to rely only on SSH-key login, or use `hashedPasswordFile` for a real production credential. This option is ignored whenever `hashedPasswordFile` is set.

*Type:*
null or string

*Default:*
`"changeme"`

*Declared by:*
- [modules/nixos/system/admin.nix](system/admin.nix)

### ft.admin.name

The username for the admin account.

*Type:*
string

*Default:*
`"admin"`

*Declared by:*
- [modules/nixos/system/admin.nix](system/admin.nix)

## ft.bulkPool

Sets up a pooled bulk storage array: reads machines/<host>/var/bulk-drives.nix for the drives you've registered (labelled bulk-*), mounts each one, combines the data and cache drives into a single pool with mergerfs, and protects the data drives with nightly SnapRAID parity syncs. Does nothing when drivesFile is unset or every drive list is empty.

### ft.bulkPool.driveBase

Directory prefix each drive is mounted under (e.g. a drive labelled bulk-data-1 mounts at /mnt/bulk/bulk-data-1).

*Type:*
string

*Default:*
`"/mnt/bulk"`

*Declared by:*
- [modules/nixos/services/bulk-pool.nix](services/bulk-pool.nix)

### ft.bulkPool.drivesFile

Path to the bulk-drives.nix file that lists your registered drives by role (parity, data, cache). Managed by ft drives-format and ft drives-sync in the consumer repo. When this is null or the file doesn't exist, the whole module is a no-op.

*Type:*
null or absolute path

*Default:*
`null`

*Declared by:*
- [modules/nixos/services/bulk-pool.nix](services/bulk-pool.nix)

### ft.bulkPool.enable

Sets up a pooled bulk storage array: reads machines/<host>/var/bulk-drives.nix for the drives you've registered (labelled bulk-*), mounts each one, combines the data and cache drives into a single pool with mergerfs, and protects the data drives with nightly SnapRAID parity syncs. Does nothing when drivesFile is unset or every drive list is empty.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/bulk-pool.nix](services/bulk-pool.nix)

### ft.bulkPool.poolMount

Where the combined mergerfs pool of data and cache drives (the @data subvolume of each) is mounted.

*Type:*
string

*Default:*
`"/mnt/bulk-pool"`

*Declared by:*
- [modules/nixos/services/bulk-pool.nix](services/bulk-pool.nix)

### ft.bulkPool.snapraid.contentFile

Path to SnapRAID's main content file, kept on the system drive rather than on any data disk.

*Type:*
string

*Default:*
`"/var/lib/snapraid/content"`

*Declared by:*
- [modules/nixos/services/bulk-pool.nix](services/bulk-pool.nix)

## ft.cachyos

Swaps the default kernel for a CachyOS build tuned for performance, pulled from the nix-cachyos flake input. Pick which build with `ft.cachyos.variant` (default: latest) — variants ending in `-x86_64-v3`, `-x86_64-v4`, or `-zen4` are tuned for specific CPU generations, and variants ending in `-lto` are compiled with link-time optimisation.

### ft.cachyos.enable

Swaps the default kernel for a CachyOS build tuned for performance, pulled from the nix-cachyos flake input. Pick which build with `ft.cachyos.variant` (default: latest) — variants ending in `-x86_64-v3`, `-x86_64-v4`, or `-zen4` are tuned for specific CPU generations, and variants ending in `-lto` are compiled with link-time optimisation.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/kernel.nix](system/kernel.nix)

### ft.cachyos.variant

Which CachyOS kernel build to use, corresponding to `linux-cachyos-<variant>` from nix-cachyos.

*Type:*
one of "latest", "latest-lto", "latest-x86_64-v3", "latest-lto-x86_64-v3", "latest-x86_64-v4", "latest-lto-x86_64-v4", "latest-zen4", "latest-lto-zen4", "bore", "bore-lto", "bore-x86_64-v3", "bore-lto-x86_64-v3", "bore-x86_64-v4", "bore-lto-x86_64-v4", "bore-zen4", "bore-lto-zen4", "eevdf", "eevdf-lto", "bmq", "bmq-lto", "lts", "lts-lto", "lts-x86_64-v3", "lts-lto-x86_64-v3", "lts-x86_64-v4", "lts-lto-x86_64-v4", "lts-zen4", "lts-lto-zen4", "rt-bore", "rt-bore-lto", "hardened", "hardened-lto", "server", "server-lto", "rc", "rc-lto", "deckify", "deckify-lto"

*Default:*
`"latest"`

*Declared by:*
- [modules/nixos/system/kernel.nix](system/kernel.nix)

## ft.cardwire

Turns on the cardwired service, which can block or unblock GPU device nodes so you can switch between integrated, hybrid, or manual GPU power modes. It works by hooking into the kernel with eBPF, so it needs a kernel built with `CONFIG_BPF_LSM=y` and `lsm=...,bpf` added to the boot parameters.

### ft.cardwire.autoApplyGpuState

When the cardwired service starts, automatically restore whichever GPU state was last saved.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/cardwire.nix](hardware/cardwire.nix)

### ft.cardwire.batteryAutoSwitch

Switch to the integrated GPU automatically whenever the machine is running on battery.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/hardware/cardwire.nix](hardware/cardwire.nix)

### ft.cardwire.enable

Turns on the cardwired service, which can block or unblock GPU device nodes so you can switch between integrated, hybrid, or manual GPU power modes. It works by hooking into the kernel with eBPF, so it needs a kernel built with `CONFIG_BPF_LSM=y` and `lsm=...,bpf` added to the boot parameters.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/cardwire.nix](hardware/cardwire.nix)

### ft.cardwire.experimentalNvidiaBlock

Turns on experimental support for blocking NVIDIA-specific device files. This switches on automatically whenever `ft.gpu` is active with the NVIDIA driver.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/hardware/cardwire.nix](hardware/cardwire.nix)

## ft.cli

Installs `just` along with a small `ft` command that runs the framework's built-in recipes from anywhere on the system. It's on by default since almost every machine wants it. It needs `ft.repoPath` set to your consumer repo's location — turn this off for machines that don't have a real checkout of your repo, like a live ISO or a test-only build.

### ft.cli.enable

Installs `just` along with a small `ft` command that runs the framework's built-in recipes from anywhere on the system. It's on by default since almost every machine wants it. It needs `ft.repoPath` set to your consumer repo's location — turn this off for machines that don't have a real checkout of your repo, like a live ISO or a test-only build.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/just.nix](system/just.nix)

## ft.containers

Sets up a container runtime — Docker or Podman, running as root or rootless — along with the real Docker Compose v2 binary and, optionally, Distrobox. Other features, like ft.komodo, build on top of this and reach the daemon through the Docker-API-compatible socket this module provides.

### ft.containers.compose.enable

Installs the real Docker Compose v2 binary (pkgs.docker-compose), which drives either runtime through its Docker-API-compatible socket. podman-compose is never used.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.dataDir

Base directory set up for docker-compose workloads and bind mounts. Owned by the rootless service account when rootless is enabled, otherwise owned by root.

*Type:*
string

*Default:*
`"/opt/containers"`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.distrobox.enable

Installs Distrobox, for running containers from other Linux distributions as environments integrated with the host, on top of whichever runtime is selected.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.enable

Sets up a container runtime — Docker or Podman, running as root or rootless — along with the real Docker Compose v2 binary and, optionally, Distrobox. Other features, like ft.komodo, build on top of this and reach the daemon through the Docker-API-compatible socket this module provides.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.rootless

Run the container runtime without root privileges. When enabled, a dedicated unprivileged account (ft.containers.user) is created with its own subuid/subgid ranges, kept logged in via systemd lingering, and given a user-level daemon socket that DOCKER_HOST points at — this runs `podman system service` or rootless dockerd depending on ft.containers.runtime. When disabled, the system daemon runs as root instead (and Podman gains its Docker-compatible socket via dockerCompat).

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.runtime

Which container runtime to use. Podman is the recommended choice for rootless setups; both runtimes expose a Docker-API-compatible socket, so the real docker-compose binary works unchanged against either one.

*Type:*
one of "docker", "podman"

*Default:*
`"podman"`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.socket

Read-only: the Docker-API-compatible socket path exposed by whichever runtime and mode are active. Other features built on this module (e.g. ft.komodo) read this and use it as DOCKER_HOST.

*Type:*
string

*Default:*
`"/run/user/2000/podman/podman.sock"`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.uid

Fixed UID/GID for the rootless service account. The rootless daemon's socket path is derived from this (/run/user/<uid>/...). Ignored when rootless = false.

*Type:*
signed integer

*Default:*
`2000`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

### ft.containers.user

Name of the unprivileged account created for rootless mode. Ignored when rootless = false.

*Type:*
string

*Default:*
`"podman"`

*Declared by:*
- [modules/nixos/services/containers.nix](services/containers.nix)

## ft.core

The baseline every machine starts from: network management, Bluetooth, network printing, zsh as the shell, and a set of everyday CLI tools. Every value here is just a default, so any host can override individual pieces.

### ft.core.enable

The baseline every machine starts from: network management, Bluetooth, network printing, zsh as the shell, and a set of everyday CLI tools. Every value here is just a default, so any host can override individual pieces.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/core.nix](system/core.nix)

### ft.core.stateVersion

The NixOS release this machine was originally installed on. NixOS uses this to decide which one-time upgrade steps to run at boot, so getting it wrong can trigger changes you don't want. Set it once when the machine is created and leave it alone after that.

*Type:*
string

*Declared by:*
- [modules/nixos/system/core.nix](system/core.nix)

## ft.cosmic

Turns on the COSMIC desktop environment along with system76-scheduler, which prioritizes process scheduling for better responsiveness, and makes sure graphics hardware acceleration is on. Pair it with `ft.cosmicGreeter` to use cosmic-greeter as the login screen, or set up a different display manager to launch the COSMIC session instead.

### ft.cosmic.enable

Turns on the COSMIC desktop environment along with system76-scheduler, which prioritizes process scheduling for better responsiveness, and makes sure graphics hardware acceleration is on. Pair it with `ft.cosmicGreeter` to use cosmic-greeter as the login screen, or set up a different display manager to launch the COSMIC session instead.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/desktops/cosmic.nix](desktops/cosmic.nix)

## ft.cosmicGreeter

Turns on cosmic-greeter as the login screen. Pair it with `ft.cosmic` to boot straight into a COSMIC session.

### ft.cosmicGreeter.enable

Turns on cosmic-greeter as the login screen. Pair it with `ft.cosmic` to boot straight into a COSMIC session.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/desktops/cosmic-greeter.nix](desktops/cosmic-greeter.nix)

## ft.deploy

Adds this machine to the fleet that can be deployed remotely with `colmena apply`. It's off by default, so you opt each machine in individually — that way local-only machines or disk images never accidentally become a remote deploy target.

### ft.deploy.buildOnTarget

Build the system on the target machine itself instead of on your control machine. Handy when targeting a different CPU architecture, or to avoid pushing a large build over the network.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/system/deploy.nix](system/deploy.nix)

### ft.deploy.enable

Adds this machine to the fleet that can be deployed remotely with `colmena apply`. It's off by default, so you opt each machine in individually — that way local-only machines or disk images never accidentally become a remote deploy target.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/deploy.nix](system/deploy.nix)

### ft.deploy.tags

Tags for this machine, so you can target a subset of the fleet with `colmena apply --on @<tag>`.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/system/deploy.nix](system/deploy.nix)

### ft.deploy.targetHost

The hostname or IP address colmena connects to over SSH. Leave it null to use the machine's own name instead, resolved through DNS or Tailscale MagicDNS.

*Type:*
null or string

*Default:*
`null`

*Declared by:*
- [modules/nixos/system/deploy.nix](system/deploy.nix)

### ft.deploy.targetUser

The SSH user colmena connects as. It needs to be able to activate system changes, so this must be root or a user with passwordless sudo.

*Type:*
string

*Default:*
`"root"`

*Declared by:*
- [modules/nixos/system/deploy.nix](system/deploy.nix)

## ft.diskBtrfs

Sets up disk partitioning for a machine: a small 1 GiB boot partition (ESP) and a btrfs root split into subvolumes for `/home`, `/nix` (with copy-on-write turned off), `/src`, and `/.snapshots`, all using zstd compression. You can optionally wrap the btrfs partition in LUKS2 encryption. When `impermanence.enable` is on, the root subvolume becomes a tmpfs ramdisk that's wiped on every boot, with a separate `@persist` subvolume added at `/persist` to hold the state that should survive. `/src` is set up so members of the `wheel` group can write to it without `sudo` — it's owned `root:wheel` with permissions `2775` and a default ACL that grants group-write on everything created inside it, plus a repair pass at boot that fixes older files created before the ACL existed. Git's global `safe.directory` protection is also turned off system-wide, because every repository under `/src` gets placed there as root by `nixos-anywhere` during provisioning.

### ft.diskBtrfs.confirmDevice

A safety check: if you change `device` away from the framework default (/dev/nvme0n1), you must also set this to the exact same value. It's a typed double-entry confirmation — if a deploy script or a person picks the wrong disk, the mismatch causes evaluation to fail before disko or nixos-anywhere ever touches the storage.

*Type:*
string

*Default:*
`""`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.device

The block device to partition, for example `/dev/nvme0n1`.

*Type:*
string

*Default:*
`"/dev/nvme0n1"`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.enable

Sets up disk partitioning for a machine: a small 1 GiB boot partition (ESP) and a btrfs root split into subvolumes for `/home`, `/nix` (with copy-on-write turned off), `/src`, and `/.snapshots`, all using zstd compression. You can optionally wrap the btrfs partition in LUKS2 encryption. When `impermanence.enable` is on, the root subvolume becomes a tmpfs ramdisk that's wiped on every boot, with a separate `@persist` subvolume added at `/persist` to hold the state that should survive. `/src` is set up so members of the `wheel` group can write to it without `sudo` — it's owned `root:wheel` with permissions `2775` and a default ACL that grants group-write on everything created inside it, plus a repair pass at boot that fixes older files created before the ACL existed. Git's global `safe.directory` protection is also turned off system-wide, because every repository under `/src` gets placed there as root by `nixos-anywhere` during provisioning.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.excludeDevices

A list of device paths that should never be used as the install target — for example, the live installer's own boot media. If `device` matches any of these, evaluation fails.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.impermanence.enable

Makes the root filesystem ephemeral: replaces the btrfs root subvolume with a tmpfs ramdisk at `/`, so anything not explicitly kept is wiped on reboot, and adds a `@persist` subvolume at `/persist` for the state you do want to keep. This turns on the impermanence NixOS module, which persists `/etc/machine-id`, `/etc/ssh`, `/var/lib`, and `/var/log` by default.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.impermanence.rootSize

How large the tmpfs ramdisk at `/` is, when `impermanence.enable` is turned on.

*Type:*
string

*Default:*
`"2G"`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.luks.enable

Encrypts the btrfs partition inside a LUKS2 container.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.luks.label

The name given to the LUKS device, which shows up under `/dev/mapper/`.

*Type:*
string

*Default:*
`"cryptroot"`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

### ft.diskBtrfs.luks.tpm.enable

Lets you unlock the LUKS volume at boot with a short PIN instead of typing the full passphrase, using a key sealed inside the TPM2 chip. Turning this on switches the initrd to systemd and adds `tpm2-device=auto` to the device's crypttab options, so boot prompts for the PIN (the TPM rate-limits guesses) while the original passphrase keyslot stays available as a fallback. It doesn't bind to any boot-chain measurements (PCRs) — the PIN itself is the secret. This option only wires up the configuration; you still need to run `systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes <luks-partition>` once after installing to actually add the TPM+PIN keyslot, since the PIN can't be declared in config. Requires `luks.enable` to also be on.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/disko-btrfs.nix](hardware/disko-btrfs.nix)

## ft.facter

Uses a hardware report to detect and configure kernel modules automatically, instead of a hand-written `hardware-configuration.nix`. Generate the report on the target machine by running `nixos-facter`, commit it to `machines/<name>/var/facter.json`, and point `ft.facter.reportPath` at it (e.g. `./var/facter.json`) from the machine's `default.nix`.

### ft.facter.enable

Uses a hardware report to detect and configure kernel modules automatically, instead of a hand-written `hardware-configuration.nix`. Generate the report on the target machine by running `nixos-facter`, commit it to `machines/<name>/var/facter.json`, and point `ft.facter.reportPath` at it (e.g. `./var/facter.json`) from the machine's `default.nix`.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/facter.nix](hardware/facter.nix)

### ft.facter.reportPath

The path to the committed `facter.json` report, relative to the flake, e.g. `reportPath = ./var/facter.json;` in the machine's `default.nix`. Leave it as `null` to skip this wiring entirely.

*Type:*
null or absolute path

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/facter.nix](hardware/facter.nix)

## ft.flatpak

Turns on the system Flatpak service and adds the Flathub remote. Once enabled, `services.flatpak.packages` (provided by nix-flatpak) becomes the place to declare system-wide Flatpak apps — set it in any machine file, profile, or other module, and every definition merges together automatically. Pair this with `ft.flatpak.frontend.enable` to also get a graphical Flathub browser.

### ft.flatpak.enable

Turns on the system Flatpak service and adds the Flathub remote. Once enabled, `services.flatpak.packages` (provided by nix-flatpak) becomes the place to declare system-wide Flatpak apps — set it in any machine file, profile, or other module, and every definition merges together automatically. Pair this with `ft.flatpak.frontend.enable` to also get a graphical Flathub browser.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/flatpak.nix](services/flatpak.nix)

### ft.flatpak.frontend.enable

Installs `ft.flatpak.frontend.package`, a graphical app for browsing and installing Flatpaks from Flathub.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/flatpak.nix](services/flatpak.nix)

### ft.flatpak.frontend.package

The package providing the graphical Flathub browser.

*Type:*
package

*Default:*
`<derivation discover-6.7.3>`

*Declared by:*
- [modules/nixos/services/flatpak.nix](services/flatpak.nix)

## ft.gaming

Sets up the Steam gaming stack: Steam itself plus GameMode, gamescope, MangoHud, Proton-GE, and a curated set of launchers and tools. Turn on ft.gaming.bigPicture to have Steam boot straight into Big Picture mode using a gamescope session.

### ft.gaming.bigPicture

Runs Steam in Big Picture mode inside a gamescope session, taking over the screen in place of the regular desktop session when you log in.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/profiles/gaming.nix](profiles/gaming.nix)

### ft.gaming.enable

Sets up the Steam gaming stack: Steam itself plus GameMode, gamescope, MangoHud, Proton-GE, and a curated set of launchers and tools. Turn on ft.gaming.bigPicture to have Steam boot straight into Big Picture mode using a gamescope session.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/profiles/gaming.nix](profiles/gaming.nix)

### ft.gaming.gamescope.enable

Turns on gamescope, the lightweight compositor Steam uses to run games in their own window or display.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/profiles/gaming.nix](profiles/gaming.nix)

### ft.gaming.gamescope.hdr

Turns on HDR output in gamescope. Your display and GPU driver both need to support HDR for this to do anything.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/profiles/gaming.nix](profiles/gaming.nix)

### ft.gaming.openFirewall

Opens the firewall ports needed for Steam Remote Play and for sending games to other devices on the local network.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/profiles/gaming.nix](profiles/gaming.nix)

## ft.gitops

Runs comin, a daemon that watches your git remotes and automatically deploys this machine's own configuration whenever new commits land: pushes to `deployBranch` are applied permanently with `switch`, while comin's per-host `testing-<hostname>` branch is applied only temporarily with `test` (a reboot reverts it). You can list multiple remotes and comin polls all of them, so no single remote being down stops deployments.

### ft.gitops.autoPromote.enable

comin deliberately never touches /nix/var/nix/profiles/system - the profile the bootloader treats as the actual default - it always deploys into its own separate system-profiles/comin profile, so a bad automated deploy can never quietly become what boots by default. Normally you'd need to manually pick the "comin" entry in the bootloader menu, or run `nixos-rebuild switch` yourself, to make a comin deployment the default. Turning this on adds a hook that does that automatically after every successful deployment of deployBranch (never comin's temporary per-host test branch, which needs to stay revertible on reboot) - trading away that safety net for convenience.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.deployBranch

The branch comin deploys permanently with `switch` (comin's remotes[].branches.main.name). This should track your production branch; when `signingKeys` is non-empty, commits on it must be signed by one of those keys.

*Type:*
string

*Default:*
`"main"`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.enable

Runs comin, a daemon that watches your git remotes and automatically deploys this machine's own configuration whenever new commits land: pushes to `deployBranch` are applied permanently with `switch`, while comin's per-host `testing-<hostname>` branch is applied only temporarily with `test` (a reboot reverts it). You can list multiple remotes and comin polls all of them, so no single remote being down stops deployments.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.pollPeriod

How often, in seconds, comin checks each remote for new commits (comin's remotes[].poller.period).

*Type:*
signed integer

*Default:*
`60`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.remotes

Ordered list of git remotes comin polls for this machine's configuration. All of them are polled together so no single remote is a point of failure — list the primary one first.

*Type:*
list of (submodule)

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.remotes.*.name

A short name for this remote (comin's remotes[].name).

*Type:*
string

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.remotes.*.tokenSecret

Name of a sops secret holding an access token for this remote. When set, the secret is decrypted and wired into comin's auth.access_token_path; leave it null to poll the remote anonymously (for a public repository). Requires ft.sops.enable.

*Type:*
null or string

*Default:*
`null`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.remotes.*.url

The git URL comin polls (comin's remotes[].url). List your primary remote first (e.g. a self-hosted Forgejo instance) and any backups after (e.g. Codeberg) — comin polls all of them so no single remote is a point of failure.

*Type:*
string

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.retry.checkInterval

How often, in seconds, the watchdog checks comin's exporter for a failure. Should comfortably exceed how long a typical evaluation, build, and switch takes, so it doesn't restart comin in the middle of an attempt.

*Type:*
signed integer

*Default:*
`300`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.retry.enable

Runs a watchdog timer that checks comin's Prometheus exporter for a failed evaluation, build, or deployment, and restarts comin.service to make it retry the current commit — up to retry.maxAttempts times before giving up until a new commit is pushed.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.retry.maxAttempts

How many times the watchdog restarts comin.service to try to recover from a failing commit, before giving up on it until a new commit arrives.

*Type:*
signed integer

*Default:*
`3`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

### ft.gitops.signingKeys

Paths to armored GPG public key files; comin only deploys a commit if it's signed by one of these (comin's gpgPublicKeyPaths). Leaving this empty disables signature checking, meaning any commit pushed to a polled branch deploys automatically — strongly discouraged outside of testing.

*Type:*
list of absolute path

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/services/gitops.nix](services/gitops.nix)

## ft.gpu

Sets up graphics drivers for NVIDIA, AMD, or Intel GPUs. It can automatically detect which vendor you have and configure PRIME offloading for hybrid (Optimus) laptops with both an integrated and a discrete GPU.

### ft.gpu.autodetect

Detects the GPU vendor and Optimus setup from the hardware report at `ft.facter.reportPath`. When on, it fills in `ft.gpu.vendor` and configures PRIME offloading automatically for Optimus laptops; turn it off to set `vendor` and the `prime` options yourself.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.enable

Sets up graphics drivers for NVIDIA, AMD, or Intel GPUs. It can automatically detect which vendor you have and configure PRIME offloading for hybrid (Optimus) laptops with both an integrated and a discrete GPU.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.enable32Bit

Adds 32-bit graphics support, needed by some older games and applications.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.nvidia.driverPackage

Which NVIDIA driver package to use — `stable` or `beta`.

*Type:*
one of "stable", "beta"

*Default:*
`"beta"`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.nvidia.enablePowerManagement

Turns on NVIDIA's power management features.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.nvidia.enableSettings

Installs the `nvidia-settings` graphical configuration tool.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.nvidia.finegrainedPowerManagement

Turns on fine-grained power management (D3cold), which lets a laptop's discrete NVIDIA GPU power down almost completely when it's idle. This only takes effect while PRIME offloading is active, since NVIDIA's own module requires offloading to be on before it will allow fine-grained power management.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.nvidia.openKernelModules

Uses NVIDIA's open-source kernel modules, which only work on Turing-generation GPUs and newer. When `autodetect` is on, this gets set automatically based on the detected GPU; turn `autodetect` off if you need to override it.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.prime.enable

Whether to enable PRIME GPU offloading (for hybrid graphics).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.prime.primaryBusId

The bus ID of the GPU connected to the display — usually the integrated GPU. Filled in automatically from the hardware report when `autodetect` is on and an Optimus setup is detected; set it explicitly to override.

*Type:*
string

*Default:*
`""`

*Example:*
`"PCI:35:0:0"`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.prime.secondaryBusId

The bus ID of the discrete GPU. Filled in automatically from the hardware report when `autodetect` is on and an Optimus setup is detected; set it explicitly to override.

*Type:*
string

*Default:*
`""`

*Example:*
`"PCI:45:0:0"`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

### ft.gpu.vendor

Which GPU vendor to configure for — `nvidia`, `amd`, or `intel`. Ignored when `autodetect` is on and a known GPU is found in the hardware report.

*Type:*
one of "nvidia", "amd", "intel"

*Default:*
`"amd"`

*Declared by:*
- [modules/nixos/hardware/gpu.nix](hardware/gpu.nix)

## ft.keepass

Installs KeePassXC and turns off the GNOME Keyring so KeePassXC is the only place secrets are stored. This matters on desktops that mix components from different environments, where GNOME Keyring's auto-unlock could otherwise bypass your hardware key authentication.

### ft.keepass.enable

Installs KeePassXC and turns off the GNOME Keyring so KeePassXC is the only place secrets are stored. This matters on desktops that mix components from different environments, where GNOME Keyring's auto-unlock could otherwise bypass your hardware key authentication.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/keepass.nix](system/keepass.nix)

## ft.komodo

Deploys Komodo's standard stack (Core, Periphery, and the FerretDB/Postgres database) using docker-compose, on top of ft.containers. Requires ft.containers.enable with compose.enable turned on. Exempt from VM smoke tests, since it pulls container images from ghcr.io at runtime.

### ft.komodo.adminPassword

Default password for the initial Komodo admin account, only used when ft.komodo.sopsEnv.enable is false (in which case it's written to the Nix store — local-only). With sopsEnv on, KOMODO_INIT_ADMIN_PASSWORD from the sops env-file overrides it.

*Type:*
string

*Default:*
`"admin"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.adminUsername

Username for the initial Komodo admin account created on first launch. Not sensitive.

*Type:*
string

*Default:*
`"admin"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.autoApply.apiEnvSecret

sops secret key holding an env-file with KOMODO_API_KEY and KOMODO_API_SECRET (create a Komodo API key once to populate this). Read by the auto-apply service to authenticate against Komodo's API.

*Type:*
string

*Default:*
`"komodo/api_env"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.autoApply.enable

Once Komodo Core is up, runs the bundled `komodo-apply` recipe from ft.repoPath to create and run the ResourceSync over Komodo's API, so every rebuild automatically reconciles Komodo with the consumer repo's containers/ directory — no clicking through the UI needed. Requires ft.cli, ft.sops and ft.repoPath, plus a sops secret (autoApply.apiEnvSecret) holding KOMODO_API_KEY and KOMODO_API_SECRET (create a Komodo API key once to get these). Exempt from VM smoke tests, since it reconciles against a live Komodo API. See NOTES.md.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.backupsPath

Path where Komodo Core writes its backup archives, bind-mounted into the Core container at /backups.

*Type:*
string

*Default:*
`"/opt/komodo/backups"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.dbPassword

Default password for the FerretDB/Postgres database. Only used when ft.komodo.sopsEnv.enable is false, in which case it's written to the Nix store (fine for local-only use). When sopsEnv is on, KOMODO_DATABASE_PASSWORD from the sops-decrypted env-file takes over instead and this value is ignored.

*Type:*
string

*Default:*
`"komodo"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.dbUsername

Username for the FerretDB/Postgres database. Not sensitive — it's baked directly into the compose config.

*Type:*
string

*Default:*
`"komodo"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.enable

Deploys Komodo's standard stack (Core, Periphery, and the FerretDB/Postgres database) using docker-compose, on top of ft.containers. Requires ft.containers.enable with compose.enable turned on. Exempt from VM smoke tests, since it pulls container images from ghcr.io at runtime.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.host

The URL this Komodo Core instance is reachable at from outside — used for OAuth redirect URLs and suggested webhook addresses.

*Type:*
string

*Default:*
`"http://localhost:9120"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.imageTag

Docker image tag to use for ghcr.io/moghtech/komodo-core and komodo-periphery.

*Type:*
string

*Default:*
`"latest"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.includeDiskMounts

Guest mount points Periphery reports disk usage for in the Komodo UI (PERIPHERY_INCLUDE_DISK_MOUNTS). Leave empty to have Periphery report every mount it detects.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.jwtSecret

Default secret used to sign Komodo's JWT tokens, used only when ft.komodo.sopsEnv.enable is false (written to the Nix store). With sopsEnv on, KOMODO_JWT_SECRET from the sops env-file overrides it.

*Type:*
string

*Default:*
`"komodo-jwt-secret"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.peripheryRootDirectory

Periphery's root directory (PERIPHERY_ROOT_DIRECTORY), bind-mounted into the periphery container at the same path. Every stack Periphery deploys, and the host side of every bind mount it manages, lives under this directory.

*Type:*
string

*Default:*
`"/etc/komodo"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.repoCachePath

Host path bind-mounted into Komodo Core at /repo-cache, where it clones git repositories for repo-based Stacks and Resource Syncs. Leave as null to keep those clones on the container's throwaway filesystem layer.

*Type:*
null or string

*Default:*
`null`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.secrets.core.enable

Like peripherySecrets, but for the komodo/core_secrets key, loaded into Core as a global [secrets] file that's [[KEY]]-interpolatable into every Stack and Deployment. This is for injecting secrets into deployed Stacks — separate from ft.komodo.sopsEnv, which covers Komodo's own login credentials. Requires sops-nix to be configured (normally via ft.sops.enable).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.secrets.periphery.enable

Declares the komodo/periphery_secrets sops key, mounts it read-only into the Periphery container, and loads it with `periphery --config-path`. Its keys can be interpolated as [[KEY]] into the Stacks this Periphery deploys, and are hidden from the Komodo UI and logs. This is for injecting secrets into deployed Stacks — separate from ft.komodo.sopsEnv, which covers Komodo's own login credentials. Requires sops-nix to be configured (normally via ft.sops.enable).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.serverName

Name given to the first Komodo server entry, and the name Periphery uses to identify itself when connecting to Core.

*Type:*
string

*Default:*
`"Local"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.sopsEnv.enable

Pulls Komodo's sensitive credentials (KOMODO_DATABASE_PASSWORD, KOMODO_INIT_ADMIN_PASSWORD, KOMODO_JWT_SECRET, KOMODO_WEBHOOK_SECRET) from a sops-decrypted env-file (ft.komodo.sopsEnv.secretName) instead of the Nix store. docker-compose loads it as the highest-priority env-file, so these credentials never touch the store. Requires sops-nix to be configured (normally via ft.sops.enable); populate the secret as KEY=VALUE lines — see NOTES.md.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.sopsEnv.secretName

sops secret key holding Komodo's credentials as an env-file (KEY=VALUE lines). Decrypted and used whenever sopsEnv.enable is true.

*Type:*
string

*Default:*
`"komodo/env"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.syncPath

Host path bind-mounted into Komodo Core at /syncs, used for 'Files on Server' Resource Syncs. Leave as null to keep those files on the container's throwaway filesystem layer.

*Type:*
null or string

*Default:*
`null`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.timezone

Timezone Komodo uses for its schedules (a tz database name, e.g. America/New_York).

*Type:*
string

*Default:*
`"Etc/UTC"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

### ft.komodo.webhookSecret

Default secret used to authenticate incoming Komodo webhooks, used only when ft.komodo.sopsEnv.enable is false (written to the Nix store). With sopsEnv on, KOMODO_WEBHOOK_SECRET from the sops env-file overrides it.

*Type:*
string

*Default:*
`"komodo-webhook-secret"`

*Declared by:*
- [modules/nixos/services/komodo.nix](services/komodo.nix)

## ft.limine

Switches the boot loader to Limine and turns off systemd-boot, since having both active at once can leave the boot loader state in a confused mess.

### ft.limine.enable

Switches the boot loader to Limine and turns off systemd-boot, since having both active at once can leave the boot loader state in a confused mess.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/limine.nix](system/limine.nix)

## ft.liveIso

Builds a NixOS live environment with everything needed to set up a new machine, using nixos-anywhere, disko, and nixos-facter. To produce an ISO, add a var/format marker file to the machine's directory (see flake-parts/lib/machines.nix) — the generator then emits it as packages.<system>.<name> instead of a nixosConfiguration. Add SSH keys via ft.liveIso.authorizedKeys in the machine's default.nix.

### ft.liveIso.authorizedKeys

SSH public keys allowed to log in as root when the live environment boots. Set this in the machine's default.nix.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/profiles/live-iso.nix](profiles/live-iso.nix)

### ft.liveIso.enable

Builds a NixOS live environment with everything needed to set up a new machine, using nixos-anywhere, disko, and nixos-facter. To produce an ISO, add a var/format marker file to the machine's directory (see flake-parts/lib/machines.nix) — the generator then emits it as packages.<system>.<name> instead of a nixosConfiguration. Add SSH keys via ft.liveIso.authorizedKeys in the machine's default.nix.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/profiles/live-iso.nix](profiles/live-iso.nix)

## ft.microvms

### ft.microvms.hostAddress

IP address of the shared host-side bridge interface (microvm0), which acts as the default gateway and DHCP server for every microVM on this host. Each VM's guest address is built from this value's /24 network portion plus its own vmAddressSuffix — change the subnet here once, rather than per instance.

*Type:*
string

*Default:*
`"10.0.100.1"`

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

### ft.microvms.instances

The set of microVM instances to run on this host. Each attribute name must match a vms/<name>/ directory (its standalone nixosConfigurations.<name>), and becomes that VM's systemd service suffix (microvm@<name>), TAP interface suffix (tap-<name>), and host share directory (/var/lib/microvm/<name>/share).

*Type:*
attribute set of (submodule)

*Default:*
`{ }`

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

### ft.microvms.instances.<name>.enable

Runs the standalone guest nixosConfigurations.<name> (built by flake-parts/vms.nix from vms/<name>/) on this host: connects it to the shared bridge (microvm0), gives it a DHCP static lease, sets up NAT so it can reach the internet, attaches a TAP interface, provisions its host-side directories, and manages its microvm@<name> systemd service. Requires KVM (/dev/kvm) and the microvm flake input. The instance name must match the vms/<name>/ directory name.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

### ft.microvms.instances.<name>.hostInterface

Name of the host's external network interface (e.g. eth0, wlan0, enp3s0), used by networking.nat to add the MASQUERADE rule that gives the VM internet access. Set to the empty string for a VM that should have no internet access. Every VM on the same host that wants internet must agree on this value.

*Type:*
string

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

### ft.microvms.instances.<name>.shareGroup

Group of the auto-provisioned host share directory (/var/lib/microvm/<name>/share), created mode 0770. Set this to a group the guest's writing service belongs to (e.g. container for a docker/Komodo guest) so it can write through the virtiofs share.

*Type:*
string

*Default:*
`"root"`

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

### ft.microvms.instances.<name>.shareOwner

Owner of the auto-provisioned host share directory (/var/lib/microvm/<name>/share), which the guest mounts over virtiofs at /srv/host-share. Set this to the user a guest service writes as when it needs write access through the share.

*Type:*
string

*Default:*
`"root"`

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

### ft.microvms.instances.<name>.vmAddressSuffix

The last octet of this VM's IP address on the shared microvm0 subnet — combined with the network portion of ft.microvms.hostAddress to build the full guest address, handed to the guest as a DHCP static lease. Must be unique among all instances on this host. (The lease's MAC and the tap interface name are derived from the instance name automatically — see modules/vm/lib.nix — so they always match the guest and never exceed Linux's 15-char interface limit.)

*Type:*
8 bit unsigned integer; between 0 and 255 (both inclusive)

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

### ft.microvms.prefixLength

Subnet prefix length shared by the host bridge and every guest interface (e.g. 24 for a /24).

*Type:*
signed integer

*Default:*
`24`

*Declared by:*
- [modules/nixos/services/microvm.nix](services/microvm.nix)

## ft.moonlight

Runs a Moonlight-compatible stream host (Sunshine) for remote desktop use and low-latency game streaming, opening the necessary firewall ports by default. Clients connect using Moonlight or Artemis. Anyone streaming from this machine also needs to be a member of the `input` group for virtual-input emulation (gamepad/keyboard/mouse) to work.

### ft.moonlight.applications

The list of Moonlight applications passed through to `services.sunshine.applications` (the `{ env; apps = [ ... ]; }` structure defining what clients can launch). Merged with this module's own defaults.

*Type:*
attribute set

*Default:*
`{ }`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

### ft.moonlight.autoStart

Starts the systemd user service automatically whenever you log into a graphical session.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

### ft.moonlight.backend

Which stream-host software to use. Only `sunshine` (nixpkgs' built-in `services.sunshine`) is currently implemented; `apollo` is reserved for a future ClassicOldSong/Apollo backend and currently fails, since Apollo isn't packaged in nixpkgs yet.

*Type:*
one of "sunshine", "apollo"

*Default:*
`"sunshine"`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

### ft.moonlight.capSysAdmin

Grants `CAP_SYS_ADMIN` on the host binary, which is needed for KMS/Wayland screen capture on many setups. Off by default since it's a privilege escalation — turn it on if screen capture fails under a Wayland session.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

### ft.moonlight.enable

Runs a Moonlight-compatible stream host (Sunshine) for remote desktop use and low-latency game streaming, opening the necessary firewall ports by default. Clients connect using Moonlight or Artemis. Anyone streaming from this machine also needs to be a member of the `input` group for virtual-input emulation (gamepad/keyboard/mouse) to work.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

### ft.moonlight.installClient

Also installs the Moonlight client (`moonlight-qt`), so this machine can view streams from other hosts, not just serve its own.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

### ft.moonlight.openFirewall

Opens the firewall ports Moonlight clients need to connect (TCP 47984/47989/47990/48010, UDP 47998-48000/48002/48010). On by default, since a stream host is unreachable without them — turn this off if you'd rather manage the ports yourself or restrict them to a VPN interface.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

### ft.moonlight.settings

Free-form settings passed straight through to `services.sunshine.settings` (e.g. `sunshine_name`, `min_log_level`, `origin_web_ui_allowed`). Merged with this module's own defaults.

*Type:*
attribute set

*Default:*
`{ }`

*Declared by:*
- [modules/nixos/services/moonlight.nix](services/moonlight.nix)

## ft.mullet

Installs every package listed in the plain text file at `ft.mullet.sourcePath`, one package name per line. This lets you add or remove packages by editing a text file instead of touching Nix code. Any name that doesn't resolve to a real package is just skipped.

### ft.mullet.enable

Installs every package listed in the plain text file at `ft.mullet.sourcePath`, one package name per line. This lets you add or remove packages by editing a text file instead of touching Nix code. Any name that doesn't resolve to a real package is just skipped.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/apps/mullet.nix](apps/mullet.nix)

### ft.mullet.sourcePath

Required: the path (relative to your flake) to the text file listing package names, one per line, e.g. `ft.mullet.sourcePath = ./var/mullet.txt;`. There's no default here, because a default path would resolve inside the framework's own repo instead of yours.

*Type:*
absolute path

*Example:*
`./var/mullet.txt`

*Declared by:*
- [modules/nixos/apps/mullet.nix](apps/mullet.nix)

## ft.nfs

Sets up NFS client mounts declared under `ft.nfs.mounts`. Each entry gives a `remotePath` (e.g. server:/share) and a `mountPoint`, and is mounted on demand — with a 10-minute idle timeout — via systemd's automount.

### ft.nfs.enable

Sets up NFS client mounts declared under `ft.nfs.mounts`. Each entry gives a `remotePath` (e.g. server:/share) and a `mountPoint`, and is mounted on demand — with a 10-minute idle timeout — via systemd's automount.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/nfs.nix](services/nfs.nix)

### ft.nfs.mounts

The set of NFS mounts to configure.

*Type:*
attribute set of (submodule)

*Default:*
`{ }`

*Declared by:*
- [modules/nixos/services/nfs.nix](services/nfs.nix)

### ft.nfs.mounts.<name>.mountPoint

Local mount point where the NFS share appears.

*Type:*
string

*Declared by:*
- [modules/nixos/services/nfs.nix](services/nfs.nix)

### ft.nfs.mounts.<name>.remotePath

Remote path of the NFS share (e.g. server:/path).

*Type:*
string

*Declared by:*
- [modules/nixos/services/nfs.nix](services/nfs.nix)

## ft.nixIndex

Whether to enable nix-index with pre-built database and comma integration.

### ft.nixIndex.comma

Turn on comma, which lets you run a command that isn't installed yet by looking it up via nix-index.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/system/nix-index.nix](system/nix-index.nix)

### ft.nixIndex.enable

Whether to enable nix-index with pre-built database and comma integration.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/nix-index.nix](system/nix-index.nix)

## ft.plasma

Turns on KDE Plasma 6 with SDDM as the login screen and the X server enabled, along with KDE Connect for pairing with phones and other devices, KWallet for storing credentials, and a curated set of KDE apps (Kate, KCalc, Spectacle, Partition Manager, and KRDC). The Elisa music player is left out by default.

### ft.plasma.enable

Turns on KDE Plasma 6 with SDDM as the login screen and the X server enabled, along with KDE Connect for pairing with phones and other devices, KWallet for storing credentials, and a curated set of KDE apps (Kate, KCalc, Spectacle, Partition Manager, and KRDC). The Elisa music player is left out by default.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/desktops/plasma.nix](desktops/plasma.nix)

## ft.plasmaBigscreen

Installs Plasma Bigscreen, a TV-friendly interface, and registers its Wayland session so it can be selected as a login option. This module is exempt from the VM smoke test requirement, since it pulls in `qtwebengine` and the full KDE Frameworks stack (which depend on the binary cache) and its main input method, HDMI-CEC, can't be tested inside a VM (it depends on real hardware).

### ft.plasmaBigscreen.cecSupport

Loads the `cec` kernel module and installs `libcec` and `v4l-utils`, so a TV remote can control Plasma Bigscreen over HDMI-CEC.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/desktops/plasma-bigscreen.nix](desktops/plasma-bigscreen.nix)

### ft.plasmaBigscreen.defaultSession

Makes the Plasma Bigscreen session the default one SDDM starts (including for autologin), instead of just offering it as one option alongside whatever other sessions are configured.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/desktops/plasma-bigscreen.nix](desktops/plasma-bigscreen.nix)

### ft.plasmaBigscreen.enable

Installs Plasma Bigscreen, a TV-friendly interface, and registers its Wayland session so it can be selected as a login option. This module is exempt from the VM smoke test requirement, since it pulls in `qtwebengine` and the full KDE Frameworks stack (which depend on the binary cache) and its main input method, HDMI-CEC, can't be tested inside a VM (it depends on real hardware).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/desktops/plasma-bigscreen.nix](desktops/plasma-bigscreen.nix)

## ft.printing

Starts CUPS along with a virtual PDF printer (CUPS-PDF) and Avahi for finding network printers via mDNS/Bonjour. Turn either piece off with `enableVirtualPdfPrinter` or `enableNetworkDiscovery`, and add hardware drivers via `extraDrivers`.

### ft.printing.enable

Starts CUPS along with a virtual PDF printer (CUPS-PDF) and Avahi for finding network printers via mDNS/Bonjour. Turn either piece off with `enableVirtualPdfPrinter` or `enableNetworkDiscovery`, and add hardware drivers via `extraDrivers`.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/printing.nix](services/printing.nix)

### ft.printing.enableNetworkDiscovery

Uses Avahi to automatically discover network printers via mDNS/Bonjour.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/services/printing.nix](services/printing.nix)

### ft.printing.enableVirtualPdfPrinter

Adds a virtual CUPS-PDF printer you can "print" to in order to save a PDF.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/services/printing.nix](services/printing.nix)

### ft.printing.extraDrivers

Additional printer driver packages to install.

*Type:*
list of package

*Default:*
`[ ]`

*Example:*
`"[ pkgs.gutenprint pkgs.hplip ]"`

*Declared by:*
- [modules/nixos/services/printing.nix](services/printing.nix)

## ft.rclone

Installs rclone and FUSE for the whole system and allows FUSE mounts to be shared with other users, so a per-user rclone mount service can expose a cloud drive (like Google Drive) at the configured mount point.

### ft.rclone.enable

Installs rclone and FUSE for the whole system and allows FUSE mounts to be shared with other users, so a per-user rclone mount service can expose a cloud drive (like Google Drive) at the configured mount point.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/rclone.nix](system/rclone.nix)

### ft.rclone.mountPoint

The name of the folder your per-user rclone mount service should mount to, e.g. a Home Manager service mounting under `~/<mountPoint>`. This is just a naming convention — this module doesn't create the mount itself.

*Type:*
string

*Default:*
`"GoogleDrive"`

*Example:*
`"GoogleDrive"`

*Declared by:*
- [modules/nixos/system/rclone.nix](system/rclone.nix)

### ft.rclone.remoteName

The rclone remote name your per-user mount service should use, e.g. `rclone mount <remoteName>: ...`. Again, just a naming convention — this module doesn't create the mount itself.

*Type:*
string

*Default:*
`"gdrive"`

*Example:*
`"gdrive"`

*Declared by:*
- [modules/nixos/system/rclone.nix](system/rclone.nix)

## ft.repoPath

Absolute path to your consumer repo on disk. Set this in your machine's config file.

*Type:*
string

*Default:*
`"/nix/ft-home"`

*Declared by:*
- [modules/nixos/system/core.nix](system/core.nix)

## ft.sops

Sets up encrypted secrets management, pointing sops-nix at `ft.repoPath/var/secrets/secrets.yaml` and decrypting with the machine's SSH host key. Turn on `ft.sops.useTPM` or `ft.sops.useYubikey` instead if you'd rather decrypt with a hardware token.

### ft.sops.enable

Sets up encrypted secrets management, pointing sops-nix at `ft.repoPath/var/secrets/secrets.yaml` and decrypting with the machine's SSH host key. Turn on `ft.sops.useTPM` or `ft.sops.useYubikey` instead if you'd rather decrypt with a hardware token.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/sops.nix](system/sops.nix)

### ft.sops.useTPM

Adds `age-plugin-tpm`, turns on the TPM2 subsystem, and points sops at the age identity in `/var/lib/sops-nix/key.txt`, which the TPM plugin fills in.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/sops.nix](system/sops.nix)

### ft.sops.useYubikey

Adds `age-plugin-yubikey`, starts the `pcscd` service for smart-card access, and points sops at the age identity stub in `/var/lib/sops-nix/key.txt`, which the YubiKey plugin fills in.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/sops.nix](system/sops.nix)

## ft.steamConfig

Turns on steam-config-nix, which lets you declare Steam launch options, per-game compatibility-tool choices, and shortcuts for non-Steam games in your configuration instead of clicking through Steam's UI. Once enabled, configure individual games under programs.steam.config.apps and programs.steam.config.nonSteamApps.

### ft.steamConfig.enable

Turns on steam-config-nix, which lets you declare Steam launch options, per-game compatibility-tool choices, and shortcuts for non-Steam games in your configuration instead of clicking through Steam's UI. Once enabled, configure individual games under programs.steam.config.apps and programs.steam.config.nonSteamApps.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/profiles/steam-config.nix](profiles/steam-config.nix)

## ft.tailscale

Joins the machine to a Tailscale mesh network, trusts the tailscale0 interface in the firewall, and installs the Trayscale tray app. Set `ft.tailscale.useRoutingFeatures = "server"` to run this machine as an exit node.

### ft.tailscale.autoJoin

Declares the `tailscale/authkey` sops secret and points
`services.tailscale.authKeyFile` at it, so tailscaled logs in and joins
the tailnet automatically on first boot instead of needing a manual
`sudo tailscale up`. Defaults to whatever `ft.sops.enable` is set to, so
any machine that already has sops enabled joins automatically with no
extra toggle. Requires a `tailscale/authkey` value in the encrypted
secrets file — it must be a reusable auth key generated in the
Tailscale admin console. If that key expires, rotate it and re-encrypt
the secrets file, or auto-join will silently stop working for any
newly built machine.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/services/tailscale.nix](services/tailscale.nix)

### ft.tailscale.enable

Joins the machine to a Tailscale mesh network, trusts the tailscale0 interface in the firewall, and installs the Trayscale tray app. Set `ft.tailscale.useRoutingFeatures = "server"` to run this machine as an exit node.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/tailscale.nix](services/tailscale.nix)

### ft.tailscale.enableTrayApp

Installs the Trayscale graphical tray application.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/services/tailscale.nix](services/tailscale.nix)

### ft.tailscale.useRoutingFeatures

Whether this machine acts as a regular Tailscale client or as a server/exit node.

*Type:*
one of "client", "server"

*Default:*
`"client"`

*Declared by:*
- [modules/nixos/services/tailscale.nix](services/tailscale.nix)

### ft.tailscale.useSSH

Turns on Tailscale's built-in SSH server (`tailscale up --ssh`), so tailnet peers can connect over SSH using their Tailscale identity instead of a separate SSH keypair — including through Tailscale's browser-based SSH Console, with no client app or authorized_keys entry required. Who can actually connect is controlled entirely by your tailnet's ACL policy in the Tailscale admin console, not by this option.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/tailscale.nix](services/tailscale.nix)

## ft.users

Creates sudo users from `superUsers` and regular unprivileged users from `normalUsers`; everyone gets zsh as their shell and membership in the common hardware/service groups. The dedicated admin account is handled separately by the `ft.admin` module.

### ft.users.enable

Creates sudo users from `superUsers` and regular unprivileged users from `normalUsers`; everyone gets zsh as their shell and membership in the common hardware/service groups. The dedicated admin account is handled separately by the `ft.admin` module.

*Type:*
boolean

*Default:*
`true`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/user.nix](system/user.nix)

### ft.users.initialPasswords

Plain-text passwords to set for individual users the first time the machine boots. Keyed by username, each value overrides the default `changeme` password. Use sops secrets instead for real production credentials.

*Type:*
attribute set of string

*Default:*
`{ }`

*Example:*
`{
  admin = "mypassword";
  guest = "guestpass";
}`

*Declared by:*
- [modules/nixos/system/user.nix](system/user.nix)

### ft.users.mainUser

The main username that other modules, like Home Manager, will apply their configuration to. Defaults to the admin account created by `ft.admin`.

*Type:*
string

*Default:*
`"admin"`

*Declared by:*
- [modules/nixos/system/user.nix](system/user.nix)

### ft.users.normalUsers

Usernames for regular accounts with no admin privileges.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/system/user.nix](system/user.nix)

### ft.users.superUsers

Extra usernames that should get sudo access.

*Type:*
list of string

*Default:*
`[ ]`

*Declared by:*
- [modules/nixos/system/user.nix](system/user.nix)

### ft.users.u2f.enable

Turns on U2F hardware-key authentication for login and sudo. Set up each user's FIDO2 credentials with `ft.users.u2f.mappings`. Users without a key on file always fall back to password login, so nobody gets locked out.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/user.nix](system/user.nix)

### ft.users.u2f.mappings

Each user's U2F key data. The attribute name is the username, and the value is the raw credential string — the part that comes after `username:` in the pam-u2f authfile format.

*Type:*
attribute set of string

*Default:*
`{ }`

*Example:*
`{
  admin = "publicKey,keyHandle";
  guest = "publicKey2,keyHandle2";
}`

*Declared by:*
- [modules/nixos/system/user.nix](system/user.nix)

## ft.vendorHw

Installs and configures the right drivers, background services, and tools for whichever hardware brand is detected in the hardware report. Covers Lenovo Legion, Razer, MSI, Logitech, Corsair, OpenRGB, ASUS ROG/TUF, and handheld gaming devices.

### ft.vendorHw.asus

Overrides autodetection for asusctl (the `asusd` daemon, fan curve control, and AuraSync) on ASUS ROG/TUF laptops. Leave as `null` to detect this automatically from the machine's manufacturer information.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.autodetect

Reads the hardware report at `ft.facter.reportPath` and turns on matching vendor tooling automatically. Turn this off to rely only on the per-brand override options below.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.corsair

Overrides autodetection for ckb-next, the driver and GUI for Corsair keyboards and mice. Leave as `null` to detect this automatically from USB vendor ID `1b1c`.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.enable

Installs and configures the right drivers, background services, and tools for whichever hardware brand is detected in the hardware report. Covers Lenovo Legion, Razer, MSI, Logitech, Corsair, OpenRGB, ASUS ROG/TUF, and handheld gaming devices.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.handheld

Overrides autodetection for InputPlumber (which remaps controls into standard gamepad input) and PowerStation (which controls TDP and power profiles), for handheld gaming devices like the Legion Go, GPD, Ayaneo, and AYN. Leave as `null` to detect this automatically from the chassis type or known manufacturer information reported by the hardware.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.lenovo

Overrides autodetection for Lenovo Legion Linux support (an out-of-tree kernel driver plus the `legiond` daemon). Leave as `null` to detect this automatically from the machine's manufacturer and family information.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.logitech

Overrides autodetection for Solaar (for Unifying/Bolt receivers) and Piper/ratbagd (for gaming mice and keyboards). Leave as `null` to detect this automatically from USB vendor ID `046d`.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.msi

Overrides autodetection for the `msi-ec` kernel module (part of the mainline kernel since Linux 5.16) and the MControlCenter GUI. Leave as `null` to detect this automatically from the machine's manufacturer information.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.openrgb

Turns on OpenRGB, a vendor-agnostic RGB lighting daemon, along with the `i2c-dev` kernel module it needs. There's no autodetection for this one — set it to `true` explicitly to enable it.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

### ft.vendorHw.razer

Overrides autodetection for OpenRazer support (kernel driver, daemon, and the Polychromatic GUI). Leave as `null` to detect this automatically from USB vendor ID `1532`.

*Type:*
null or boolean

*Default:*
`null`

*Declared by:*
- [modules/nixos/hardware/vendor-hw.nix](hardware/vendor-hw.nix)

## ft.vicinae

Registers the upstream vicinae.cachix.org binary cache, so the Vicinae launcher (ft.vicinae.enable in Home Manager) doesn't have to compile its Qt6/C++ stack from source.

### ft.vicinae.enable

Registers the upstream vicinae.cachix.org binary cache, so the Vicinae launcher (ft.vicinae.enable in Home Manager) doesn't have to compile its Qt6/C++ stack from source.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/vicinae.nix](services/vicinae.nix)

### ft.vicinae.inputServer.enable

Wraps vicinae-input-server with cap_dac_override (via security.wrappers), giving it raw input-device access for Vicinae's global-hotkey and keystroke-injection features. This bypasses the wrapped binary's normal file-permission checks, so leave it disabled if Vicinae is only ever launched through a compositor-bound shortcut (e.g. a KWin global shortcut running `vicinae toggle`).

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/services/vicinae.nix](services/vicinae.nix)

## ft.virt

Sets up virtual machine support with libvirt/KVM and virt-manager, and adds `ft.users.mainUser` to the libvirtd group so they can manage VMs. You can also turn on `ft.virt.enableVmwareHost` for VMware Workstation, `ft.virt.enableIncus` for Incus containers, and `ft.virt.enableSpiceUsbRedirection` to pass USB devices through to VMs.

### ft.virt.enable

Sets up virtual machine support with libvirt/KVM and virt-manager, and adds `ft.users.mainUser` to the libvirtd group so they can manage VMs. You can also turn on `ft.virt.enableVmwareHost` for VMware Workstation, `ft.virt.enableIncus` for Incus containers, and `ft.virt.enableSpiceUsbRedirection` to pass USB devices through to VMs.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/system/virt.nix](system/virt.nix)

### ft.virt.enableIncus

Turn on Incus, the LXD-based container and VM hypervisor.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/system/virt.nix](system/virt.nix)

### ft.virt.enableSpiceUsbRedirection

Turn on SPICE USB redirection, letting VMs use USB devices plugged into the host.

*Type:*
boolean

*Default:*
`true`

*Declared by:*
- [modules/nixos/system/virt.nix](system/virt.nix)

### ft.virt.enableVmwareHost

Turn on support for running VMware Workstation on this machine.

*Type:*
boolean

*Default:*
`false`

*Declared by:*
- [modules/nixos/system/virt.nix](system/virt.nix)

## ft.wine

Installs Bottles, Wine (the WOW64 build), and Winetricks so you can run Windows applications outside of Steam.

### ft.wine.enable

Installs Bottles, Wine (the WOW64 build), and Winetricks so you can run Windows applications outside of Steam.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/profiles/wine.nix](profiles/wine.nix)

## ft.yubikey

Installs YubiKey management tools (`yubikey-manager`, `yubico-piv-tool`, `pam_u2f`), turns on the `pcscd` smart-card service, and activates `ft.users.u2f` so YubiKeys can be used for login. Set each user's FIDO2 credentials with `ft.users.u2f.mappings` in your machine config.

### ft.yubikey.enable

Installs YubiKey management tools (`yubikey-manager`, `yubico-piv-tool`, `pam_u2f`), turns on the `pcscd` smart-card service, and activates `ft.users.u2f` so YubiKeys can be used for login. Set each user's FIDO2 credentials with `ft.users.u2f.mappings` in your machine config.

*Type:*
boolean

*Default:*
`false`

*Example:*
`true`

*Declared by:*
- [modules/nixos/hardware/yubikey.nix](hardware/yubikey.nix)

