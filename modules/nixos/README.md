## ft\.bulkPool\.enable



Reads machines/\<host>/var/bulk-drives\.nix to discover registered bulk drives (labelled bulk-\*), mounts each btrfs root, pools data and cache drives via mergerfs, protects data drives with snapraid parity, and runs a nightly snapraid-btrfs sync\. A no-op when drivesFile is unset or all drive lists are empty\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool.nix)



## ft\.bulkPool\.driveBase

Directory prefix for individual drive mount points (e\.g\. /mnt/bulk/bulk-data-1 mounts the btrfs root of that drive)\.



*Type:*
string



*Default:*

```nix
"/mnt/bulk"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool.nix)



## ft\.bulkPool\.drivesFile



Path to the bulk-drives\.nix file listing registered drive labels by role (parity, data, cache)\. Managed by ft drives-format and ft drives-sync in the consumer repo\. When null or the file is absent, the module is a complete no-op\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool.nix)



## ft\.bulkPool\.poolMount



Mount point for the mergerfs union pool of data and cache drives (@data subvolume of each)\.



*Type:*
string



*Default:*

```nix
"/mnt/bulk-pool"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool.nix)



## ft\.bulkPool\.snapraid\.contentFile



Primary snapraid content file path on the system drive (not on a data disk)\.



*Type:*
string



*Default:*

```nix
"/var/lib/snapraid/content"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/bulk-pool.nix)



## ft\.cachyos\.enable



Replaces the default kernel with a CachyOS-optimised build sourced from the nix-cachyos flake input\. Select a variant with ` ft.cachyos.variant ` (default: latest)\. Append -x86_64-v3, -x86_64-v4, or -zen4 for microarchitecture-optimised builds\. Append -lto for LTO-compiled editions\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/kernel\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/kernel.nix)



## ft\.cachyos\.variant



CachyOS kernel variant\. Maps to linux-cachyos-\<variant> from nix-cachyos\.



*Type:*
one of “latest”, “latest-lto”, “latest-x86_64-v3”, “latest-lto-x86_64-v3”, “latest-x86_64-v4”, “latest-lto-x86_64-v4”, “latest-zen4”, “latest-lto-zen4”, “bore”, “bore-lto”, “bore-x86_64-v3”, “bore-lto-x86_64-v3”, “bore-x86_64-v4”, “bore-lto-x86_64-v4”, “bore-zen4”, “bore-lto-zen4”, “eevdf”, “eevdf-lto”, “bmq”, “bmq-lto”, “lts”, “lts-lto”, “lts-x86_64-v3”, “lts-lto-x86_64-v3”, “lts-x86_64-v4”, “lts-lto-x86_64-v4”, “lts-zen4”, “lts-lto-zen4”, “rt-bore”, “rt-bore-lto”, “hardened”, “hardened-lto”, “server”, “server-lto”, “rc”, “rc-lto”, “deckify”, “deckify-lto”



*Default:*

```nix
"latest"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/kernel\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/kernel.nix)



## ft\.cardwire\.enable



Enables the cardwired D-Bus service, which uses eBPF LSM hooks to block and unblock GPU device nodes for integrated/hybrid/manual GPU power control\. Requires a kernel with CONFIG_BPF_LSM=y and lsm=…,bpf in boot parameters\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire.nix)



## ft\.cardwire\.autoApplyGpuState



Automatically restore the last saved GPU state when the cardwired service starts\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire.nix)



## ft\.cardwire\.batteryAutoSwitch



Automatically switch to integrated GPU mode when running on battery power\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire.nix)



## ft\.cardwire\.experimentalNvidiaBlock



Enable experimental blocking of NVIDIA-specific device files\. Enabled automatically when ft\.gpu is active with the NVIDIA driver\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/cardwire.nix)



## ft\.cli\.enable



Installs just and a thin ` ft ` wrapper that invokes the repo’s ` scripts/ft.just ` justfile from any working directory\. Requires ` ft.repoPath ` to point to your consumer repo root\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/just\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/just.nix)



## ft\.core\.enable



Sets the system-wide baseline every host shares: NetworkManager, Bluetooth, CUPS/Avahi printing, flakes + nix-command, store auto-optimisation, locale (en_US\.UTF-8), zsh shell, and core CLI packages\. All values use mkDefault and can be overridden per host\.



*Type:*
boolean



*Default:*

```nix
true
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/core\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/core.nix)



## ft\.core\.stateVersion



The NixOS release version this machine was *first installed* on\. Controls which state migration paths activate on boot — setting this wrong triggers unwanted migrations\. Set it once at machine creation and never change it\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/core\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/core.nix)



## ft\.cosmic\.enable



Enables the COSMIC desktop environment with cosmic-greeter as the display manager and system76-scheduler for performance-aware process scheduling\. Also ensures graphics hardware acceleration is active\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/desktops/cosmic\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/desktops/cosmic.nix)



## ft\.diskBtrfs\.enable



Configures a GPT disk with a 1 GiB ESP and a btrfs root partition containing subvolumes @home (/home), @nix (/nix, nodatacow), @src (/src), and @snapshots (/\.snapshots) with zstd compression\. Optionally wraps the btrfs partition in a LUKS2 container\. When impermanence\.enable is set, replaces the @ root subvolume with a tmpfs ramdisk and adds @persist (/persist) for durable state\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs.nix)



## ft\.diskBtrfs\.device



Block device to partition (e\.g\. /dev/nvme0n1)\.



*Type:*
string



*Default:*

```nix
"/dev/nvme0n1"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs.nix)



## ft\.diskBtrfs\.impermanence\.enable



Replace the btrfs @ root subvolume with a tmpfs ramdisk at / and add @persist (/persist) for durable state\. Enables the impermanence NixOS module with /etc/machine-id, /etc/ssh, /var/lib, and /var/log persisted by default\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs.nix)



## ft\.diskBtrfs\.impermanence\.rootSize



Size of the tmpfs ramdisk mounted at / when impermanence\.enable is true\.



*Type:*
string



*Default:*

```nix
"2G"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs.nix)



## ft\.diskBtrfs\.luks\.enable



Wrap the btrfs partition in a LUKS2 container\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs.nix)



## ft\.diskBtrfs\.luks\.label



Name of the LUKS dm-crypt device (appears under /dev/mapper/)\.



*Type:*
string



*Default:*

```nix
"cryptroot"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/disko-btrfs.nix)



## ft\.dockervm\.enable



Boots a Cloud Hypervisor microVM attached to a host TAP bridge, installs rootful Docker and docker-compose inside the guest, and routes guest internet traffic via host NAT\. Requires KVM (/dev/kvm) on the host and the microvm flake input (bundled with fast-track-nix)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.composeVolumeSize



Size of the /opt/compose volume in MiB (image stored at /var/lib/microvm/\<vmName>/compose\.img on the host)\.



*Type:*
signed integer



*Default:*

```nix
10240
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.dockerVolumeSize



Size of the persistent Docker data volume in MiB (image stored at /var/lib/microvm/\<vmName>/docker\.img on the host)\.



*Type:*
signed integer



*Default:*

```nix
20480
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.guacamole\.enable



Deploy Apache Guacamole (guacd, web front-end, and PostgreSQL) inside the VM via OCI containers\. The web interface is exposed on guacamole\.port within the VM\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.guacamole\.dbPassword



PostgreSQL password for the Guacamole database\. Stored in the Nix store — suitable only for local-only deployments\.



*Type:*
string



*Default:*

```nix
"guacamole"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.guacamole\.imageTag



Image tag for guacamole/guacd and guacamole/guacamole on Docker Hub\.



*Type:*
string



*Default:*

```nix
"latest"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.guacamole\.port



Port inside the VM on which the Guacamole web interface listens\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8084
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.hostAddress



IP address of the host-side bridge interface (microvm0); becomes the VM’s default gateway\.



*Type:*
string



*Default:*

```nix
"10.0.100.1"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.hostInterface



Name of the host’s external network interface (e\.g\. eth0, wlp3s0, enp3s0)\. Required by networking\.nat to add the MASQUERADE rule that gives the VM internet access\. Must be set when enable = true\.



*Type:*
string



*Default:*

```nix
""
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.enable



Deploy a Komodo instance (core + periphery + FerretDB) inside the VM\. Container data is stored on the docker\.img volume; backups are written to /opt/komodo/backups on the host via virtiofs\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.adminPassword



Initial Komodo admin password\. Stored in the Nix store — change after first login\.



*Type:*
string



*Default:*

```nix
"admin"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.adminUsername



Initial Komodo admin username created on first launch\.



*Type:*
string



*Default:*

```nix
"admin"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.dbPassword



Password for the FerretDB/Postgres database\. Stored in the Nix store — suitable only for local-only deployments\.



*Type:*
string



*Default:*

```nix
"komodo"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.dbUsername



Username for the FerretDB/Postgres database\.



*Type:*
string



*Default:*

```nix
"komodo"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.host



Public URL of the Komodo Core instance; used for OAuth redirect URLs and webhook suggestions\.



*Type:*
string



*Default:*

```nix
"http://10.0.100.2:9120"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.imageTag



Docker image tag for ghcr\.io/moghtech/komodo-core and komodo-periphery\.



*Type:*
string



*Default:*

```nix
"latest"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.jwtSecret



Secret used to sign Komodo JWT tokens\. Stored in the Nix store\.



*Type:*
string



*Default:*

```nix
"komodo-jwt-secret"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.serverName



Name for the first Komodo server entry, and the name Periphery uses to connect to Core\.



*Type:*
string



*Default:*

```nix
"Local"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.timezone



Timezone for Komodo schedules (tz database name, e\.g\. America/New_York)\.



*Type:*
string



*Default:*

```nix
"Etc/UTC"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.komodo\.webhookSecret



Secret used to authenticate incoming Komodo webhooks\. Stored in the Nix store\.



*Type:*
string



*Default:*

```nix
"komodo-webhook-secret"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.mem



Memory in MiB assigned to the VM\.



*Type:*
signed integer



*Default:*

```nix
2048
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.prefixLength



Subnet prefix length shared by the host bridge and VM interface (e\.g\. 24 for /24)\.



*Type:*
signed integer



*Default:*

```nix
24
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.sshAuthorizedKeys



SSH public keys authorized to log in as root inside the VM\. When non-empty, enables OpenSSH server in the guest on port 22 (the VM is only reachable from the host bridge, so exposure is limited to the host)\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.vcpus



Number of vCPUs assigned to the VM\.



*Type:*
signed integer



*Default:*

```nix
2
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.vmAddress



Static IP address assigned to the VM’s primary network interface\.



*Type:*
string



*Default:*

```nix
"10.0.100.2"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.vmMac



MAC address assigned to the VM’s TAP-backed network interface\. Must be locally administered (first octet 02)\.



*Type:*
string



*Default:*

```nix
"02:00:00:00:00:01"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.vmName



Name for the microvm instance\. Used as the systemd service name, guest hostname, and TAP interface suffix (tap-\<vmName>)\.



*Type:*
string



*Default:*

```nix
"docker-vm"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.dockervm\.vsockCid



vsock context ID (CID) for the VM\. When set, enables systemd-notify support for cloud-hypervisor and the host service will wait for the VM to signal readiness — do not set this if any service blocks multi-user\.target for a long time (e\.g\. first-boot image pulls)\. Must be unique per host (valid range: 3–4294967293)\.



*Type:*
null or signed integer



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-docker.nix)



## ft\.facter\.enable



Points the nixos-facter NixOS module at a facter\.json report committed to the machine directory\. Replaces hardware-configuration\.nix for kernel-module detection\. Generate the report on the target with ` nixos-facter `, commit it to machines/\<name>/var/facter\.json, and set ft\.facter\.reportPath = \./var/facter\.json in the machine’s default\.nix\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/facter\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/facter.nix)



## ft\.facter\.reportPath



Flake-relative path to the facter\.json report committed in the consumer repo, e\.g\. reportPath = \./var/facter\.json; from the machine’s default\.nix\. Null disables the report wiring\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/facter\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/facter.nix)



## ft\.gaming\.enable



Enables Steam with GameMode, gamescope, MangoHud, Proton-GE, and a curated set of launchers and tools\. Set ft\.gaming\.bigPicture = true to boot Steam into Big Picture mode via a gamescope session\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming.nix)



## ft\.gaming\.bigPicture



Run Steam inside a gamescope session (Big Picture mode), replacing the desktop session on login\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming.nix)



## ft\.gaming\.gamescope\.enable



Enable the gamescope micro-compositor\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming.nix)



## ft\.gaming\.gamescope\.hdr



Enable HDR output in gamescope\. Requires an HDR-capable display and a supporting GPU driver\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming.nix)



## ft\.gaming\.openFirewall



Open firewall ports for Steam Remote Play and local network game transfers\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/gaming.nix)



## ft\.gpu\.enable



Configures graphics drivers for NVIDIA, AMD, or Intel GPUs, with optional facter-driven autodetection of the vendor and PRIME offloading for hybrid (Optimus) laptops\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.enable32Bit



Enable 32-bit graphics support (for older games/applications)\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.autodetect



Detect GPU vendor and Optimus configuration from ft\.facter\.reportPath\. When true, sets ft\.gpu\.vendor and configures PRIME offloading automatically for Optimus setups\. Set to false to use the vendor and prime options directly\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.nvidia\.enablePowerManagement



Enable NVIDIA power management\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.nvidia\.enableSettings



Enable the nvidia-settings GUI\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.nvidia\.driverPackage



NVIDIA driver package to use (stable or beta)\.



*Type:*
one of “stable”, “beta”



*Default:*

```nix
"beta"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.nvidia\.finegrainedPowerManagement



Enable fine-grained NVIDIA power management (D3cold) for laptops/hybrid systems\. Only applied while PRIME offloading is active, since the upstream nvidia module asserts fine-grained power management requires offload\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.nvidia\.openKernelModules



Use open-source NVIDIA kernel modules (Turing+)\. When autodetect = true this is set automatically based on the GPU device ID; set autodetect = false to override\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.prime\.enable



Whether to enable PRIME GPU offloading (for hybrid graphics)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.prime\.primaryBusId



Bus ID of the GPU connected to the display (e\.g\. iGPU)\. Derived automatically from facter\.json when autodetect = true and an Optimus setup is detected; set explicitly to override\.



*Type:*
string



*Default:*

```nix
""
```



*Example:*

```nix
"PCI:35:0:0"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.prime\.secondaryBusId



Bus ID of the discrete GPU\. Derived automatically from facter\.json when autodetect = true and an Optimus setup is detected; set explicitly to override\.



*Type:*
string



*Default:*

```nix
""
```



*Example:*

```nix
"PCI:45:0:0"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.gpu\.vendor



Primary GPU vendor (nvidia, amd, or intel)\. Ignored when autodetect = true and a known GPU is found in facter\.json\.



*Type:*
one of “nvidia”, “amd”, “intel”



*Default:*

```nix
"amd"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/gpu.nix)



## ft\.guacamole\.enable



Deploys Apache Guacamole (guacd, web front-end, and PostgreSQL) as OCI containers on a dedicated guacamole-net network\. Requires an OCI runtime (Docker or Podman) already enabled on the host\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.guacamole\.dataDir



Base directory for Guacamole persistent data: PostgreSQL data, drive files, session recordings, and the generated initdb schema\.



*Type:*
string



*Default:*

```nix
"/opt/guacamole"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.guacamole\.dbName



PostgreSQL database name used by Guacamole\.



*Type:*
string



*Default:*

```nix
"guacamole_db"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.guacamole\.dbPassword



PostgreSQL password\. Stored in the Nix store — suitable only for local-only deployments\. Use sops-nix or a similar secrets manager for production\.



*Type:*
string



*Default:*

```nix
"guacamole"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.guacamole\.dbUsername



PostgreSQL username\.



*Type:*
string



*Default:*

```nix
"guacamole"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.guacamole\.imageTag



Image tag for guacamole/guacd and guacamole/guacamole on Docker Hub\.



*Type:*
string



*Default:*

```nix
"latest"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.guacamole\.port



Host port mapped to the Guacamole web interface (container port 8080)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8084
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.guacamole\.runtime



OCI container runtime backend\. Must match virtualisation\.oci-containers\.backend when other modules also use oci-containers on the same host\.



*Type:*
one of “docker”, “podman”



*Default:*

```nix
"docker"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/guacamole.nix)



## ft\.hermesVm\.enable



Boots a Cloud Hypervisor microVM providing an isolated NixOS environment for the Nous Research Hermes agent\. The guest reaches the host’s existing Ollama instance via the bridge at ollamaUrl — no Ollama server runs inside the VM\. Requires KVM on the host and the microvm flake input (bundled with fast-track-nix)\. VM smoke test exempt: nested KVM is unavailable in CI\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.hermesApiPort



Port on which the Hermes gateway API server listens inside the VM\. Reachable from the host at http://\<vmAddress>:\<hermesApiPort>\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8642
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.hostAddress



IP address of the host-side bridge interface (hermes-br); becomes the VM’s default gateway\.



*Type:*
string



*Default:*

```nix
"10.0.102.1"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.hostInterface



Host external network interface (e\.g\. eth0, enp3s0) for NAT\. When set, the guest gets outbound internet access\. Leave empty if only host–guest communication is needed\.



*Type:*
string



*Default:*

```nix
""
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.mem



Memory in MiB assigned to the VM\.



*Type:*
signed integer



*Default:*

```nix
2048
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.ollamaUrl



Base URL of the Ollama instance on the host\. Exposed to the guest as OPENAI_BASE_URL with /v1 appended so hermes-agent uses it as the LLM backend\. Requires Ollama to be bound to 0\.0\.0\.0 or the bridge address on the host\.



*Type:*
string



*Default:*

```nix
"http://10.0.102.1:11434"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.openaiApiKey



Value for OPENAI_API_KEY inside the guest\. Ollama ignores the key; set this when pointing at a provider that enforces authentication\.



*Type:*
string



*Default:*

```nix
"ollama"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.prefixLength



Subnet prefix length shared by the host bridge and VM interface (e\.g\. 24 for /24)\.



*Type:*
signed integer



*Default:*

```nix
24
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.sshAuthorizedKeys



SSH public keys authorized to log in as root inside the VM\. When non-empty, enables OpenSSH in the guest on port 22\. The VM is only reachable from the host bridge, so exposure is limited to the host\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.vcpus



Number of vCPUs assigned to the VM\.



*Type:*
signed integer



*Default:*

```nix
2
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.vmAddress



Static IP address assigned to the VM’s primary network interface\.



*Type:*
string



*Default:*

```nix
"10.0.102.2"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.vmMac



MAC address assigned to the VM’s TAP-backed network interface\. Must be locally administered (first octet 02)\. Change this if running alongside ft\.dockervm to avoid collisions\.



*Type:*
string



*Default:*

```nix
"02:00:00:00:01:01"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.hermesVm\.vmName



Name for the microvm instance\. Used as the systemd service name, guest hostname, and TAP interface suffix (tap-\<vmName>)\.



*Type:*
string



*Default:*

```nix
"hermes-vm"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm-hermes.nix)



## ft\.keepass\.enable



Installs KeePassXC and force-disables the GNOME Keyring so KeePassXC becomes the sole secret storage backend\. Useful on COSMIC or hybrid DE setups where GNOME Keyring’s auto-unlock would bypass hardware key authentication\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/keepass\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/keepass.nix)



## ft\.komodo\.enable



Deploys Komodo Core, Periphery, and PostgreSQL as rootless Podman containers under the podman service user\. Requires ft\.podmanRootless\.enable = true\. Populate the sops secret keys documented in NOTES\.md before the first deploy\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/komodo\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/komodo.nix)



## ft\.limine\.enable



Enables the Limine UEFI bootloader and disables systemd-boot to prevent loader state conflicts\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/limine\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/limine.nix)



## ft\.liveIso\.enable



Configures a NixOS live environment with all tools needed to provision a new machine via nixos-anywhere, disko, and nixos-facter\. Build the ISO with lib\.mkLiveIso; inject SSH keys and additional config via its extraModules argument\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/live-iso\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/live-iso.nix)



## ft\.liveIso\.authorizedKeys



SSH public keys authorised for the root account on boot\. Pass via extraModules in lib\.mkLiveIso\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/live-iso\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/live-iso.nix)



## ft\.microvms



Set of microVM instances to provision on this host\. Each attribute key becomes the VM name, systemd service suffix, guest hostname, and TAP interface suffix (tap-\<name>)\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.enable



Provisions a Cloud Hypervisor microVM on the host: creates a bridge interface (microvm0), configures NAT for guest internet access, attaches a TAP interface, and manages the microvm@\<name> systemd service\. Requires KVM (/dev/kvm) and the microvm flake input\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.extraGuestConfig



Additional NixOS module merged into the guest configuration\. Use this to inject application-level services (e\.g\. ft\.ociStack) without modifying this generic infrastructure module\.



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.hostAddress



IP address of the host-side bridge interface (microvm0); becomes the VM’s default gateway\. All VMs on the same host share this bridge and must agree on this value\.



*Type:*
string



*Default:*

```nix
"10.0.100.1"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.hostInterface



Name of the host’s external network interface (e\.g\. eth0, wlan0, enp3s0)\. Used by networking\.nat to add the MASQUERADE rule that gives the VM internet access\. All VMs on the same host must agree on this value\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.mem



Memory in MiB assigned to the VM\.



*Type:*
signed integer



*Default:*

```nix
2048
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.prefixLength

Subnet prefix length shared by the host bridge and VM interface (e\.g\. 24 for /24)\.



*Type:*
signed integer



*Default:*

```nix
24
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.shares



Host directories shared into the guest via virtiofs\. Requires cloud-hypervisor (Firecracker does not support virtiofs)\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.shares\.\*\.mountPoint



Mount point inside the guest\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.shares\.\*\.proto



Filesystem sharing protocol (virtiofs or 9p)\.



*Type:*
string



*Default:*

```nix
"virtiofs"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.shares\.\*\.source



Absolute path on the host to share into the guest\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.shares\.\*\.tag



Unique virtiofs tag for this share\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.sshAuthorizedKeys



SSH public keys authorized to log in as root inside the VM\. When non-empty, enables OpenSSH server in the guest on port 22 (the VM is only reachable from the host bridge)\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.vcpus



Number of vCPUs assigned to the VM\.



*Type:*
signed integer



*Default:*

```nix
2
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.vmAddress



Static IP address assigned to the VM’s primary network interface\. Must be unique within the host bridge subnet\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.vmMac



MAC address assigned to the VM’s TAP-backed network interface\. Must be locally administered (first octet 02) and unique per host\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.volumes



Persistent disk images attached to the guest\. Each entry creates a host-side image file and mounts it at the given path inside the VM\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.volumes\.\*\.image



Absolute path to the host-side disk image file\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.volumes\.\*\.mountPoint



Mount point inside the guest\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.volumes\.\*\.size



Size of the disk image in MiB\.



*Type:*
signed integer

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.microvms\.\<name>\.vsockCid



vsock context ID (CID) for the VM\. When set, enables systemd-notify support and the host service will wait for the VM to signal readiness — do not set this if any service blocks multi-user\.target for a long time (e\.g\. first-boot image pulls)\. Must be unique per host (valid range: 3–4294967293)\.



*Type:*
null or signed integer



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/microvm.nix)



## ft\.mullet\.enable



Installs every package named in the newline-delimited file at ` ft.mullet.sourcePath ` into the system closure\. Lets a consumer add or remove packages by editing a plain text file instead of editing Nix\. Unresolved names are silently skipped\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/apps/mullet\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/apps/mullet.nix)



## ft\.mullet\.sourcePath



Required: flake-relative path to the flat newline-delimited text file tracking imperatively-managed package attribute names\. Set it in your machine config, e\.g\. ` ft.mullet.sourcePath = ./var/mullet.txt; `\. No default is provided because a framework-relative default would resolve into the framework repo, not the consumer’s\.



*Type:*
absolute path



*Example:*

```nix
./var/mullet.txt
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/apps/mullet\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/apps/mullet.nix)



## ft\.nfs\.enable



Configures NFS client mounts declared under ` ft.nfs.mounts `\. Each entry specifies a ` remotePath ` (e\.g\. server:/share) and a ` mountPoint `, and is auto-mounted on demand with a 10-minute idle timeout via systemd\.automount\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs.nix)



## ft\.nfs\.mounts



Attribute set of NFS mounts to configure\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs.nix)



## ft\.nfs\.mounts\.\<name>\.mountPoint



Local mount point for the NFS share\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs.nix)



## ft\.nfs\.mounts\.\<name>\.remotePath



Remote path of the NFS share (e\.g\., server:/path)\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/nfs.nix)



## ft\.nixIndex\.enable



Whether to enable nix-index with pre-built database and comma integration\.



*Type:*
boolean



*Default:*

```nix
true
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/nix-index\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/nix-index.nix)



## ft\.nixIndex\.comma



Enable comma — run uninstalled commands via nix-index\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/nix-index\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/nix-index.nix)



## ft\.ociStack\.enable



Enables a rootful OCI container runtime (Docker or Podman) with docker-compose, and optionally deploys a Komodo core + periphery + FerretDB stack\. Designed for use inside a microVM guest; provision the Docker data volume separately via ft\.microvms\.volumes\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.enable



Deploy a Komodo core + periphery + FerretDB stack via docker-compose\. Container data is stored on the Docker volume; backups are written to komodo\.backupsPath\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.adminPassword



Initial Komodo admin password\. Stored in the Nix store — change after first login\.



*Type:*
string



*Default:*

```nix
"admin"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.adminUsername



Initial Komodo admin username created on first launch\.



*Type:*
string



*Default:*

```nix
"admin"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.backupsPath



Path inside the guest where Komodo writes backup archives\. When using the ft\.dockervm wrapper this is on a virtiofs share backed by the host\.



*Type:*
string



*Default:*

```nix
"/opt/komodo/backups"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.dbPassword



Password for the FerretDB/Postgres database\. Stored in the Nix store — suitable only for local-only deployments\.



*Type:*
string



*Default:*

```nix
"komodo"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.dbUsername



Username for the FerretDB/Postgres database\.



*Type:*
string



*Default:*

```nix
"komodo"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.host



Externally accessible URL for the Komodo Core instance; used for OAuth redirect URLs and webhook suggestions\. Override with the VM’s IP when deploying inside a microVM (e\.g\. http://10\.0\.100\.2:9120)\.



*Type:*
string



*Default:*

```nix
"http://localhost:9120"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.imageTag



Docker image tag for ghcr\.io/moghtech/komodo-core and komodo-periphery\.



*Type:*
string



*Default:*

```nix
"latest"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.jwtSecret



Secret used to sign Komodo JWT tokens\. Stored in the Nix store\.



*Type:*
string



*Default:*

```nix
"komodo-jwt-secret"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.requireMountUnit



Systemd mount unit that must be active before the Komodo service starts (e\.g\. opt-komodo\.mount when backupsPath is on a virtiofs share)\. Set automatically by ft\.dockervm; null disables the dependency\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.serverName



Name for the first Komodo server entry, and the name Periphery uses when connecting to Core\.



*Type:*
string



*Default:*

```nix
"Local"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.timezone



Timezone for Komodo schedules (tz database name, e\.g\. America/New_York)\.



*Type:*
string



*Default:*

```nix
"Etc/UTC"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.komodo\.webhookSecret



Secret used to authenticate incoming Komodo webhooks\. Stored in the Nix store\.



*Type:*
string



*Default:*

```nix
"komodo-webhook-secret"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.ociStack\.runtime



OCI container runtime\. Both options run rootful\. With podman, Docker CLI compatibility and the Docker socket are enabled so that compose files using /var/run/docker\.sock work unchanged\.



*Type:*
one of “docker”, “podman”



*Default:*

```nix
"docker"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/oci-stack.nix)



## ft\.plasma\.enable



Enables KDE Plasma 6 with X server, KDE Connect for device pairing, KWallet for credential storage, and a curated set of KDE apps (kate, kcalc, spectacle, partitionmanager, krdc)\. Elisa music player is excluded by default\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/desktops/plasma\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/desktops/plasma.nix)



## ft\.podmanRootless\.enable



Creates a dedicated unprivileged ‘podman’ user with subuid/subgid mappings, enables cgroup v2, configures a persistent user-level Podman socket via systemd lingering, and provisions /opt/containers\. Installs docker-compose pointed at the rootless socket\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/podman-rootless\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/podman-rootless.nix)



## ft\.podmanRootless\.uid



Fixed UID and GID assigned to the podman service user\. Derives the Podman socket path at /run/user/\<uid>/podman/podman\.sock for DOCKER_HOST\.



*Type:*
signed integer



*Default:*

```nix
2000
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/podman-rootless\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/podman-rootless.nix)



## ft\.printing\.enable



Starts CUPS with a virtual PDF printer (CUPS-PDF) and Avahi for mDNS/Bonjour network printer discovery\. Disable either sub-feature with ` enableVirtualPdfPrinter ` or ` enableNetworkDiscovery `\. Add hardware drivers via ` extraDrivers `\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing.nix)



## ft\.printing\.enableNetworkDiscovery



Enable Avahi for network printer discovery (mDNS/Bonjour)\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing.nix)



## ft\.printing\.enableVirtualPdfPrinter



Enable CUPS-PDF virtual printer\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing.nix)



## ft\.printing\.extraDrivers



List of additional printer driver packages\.



*Type:*
list of package



*Default:*

```nix
[ ]
```



*Example:*

```nix
"[ pkgs.gutenprint pkgs.hplip ]"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/printing.nix)



## ft\.rclone\.enable



Installs rclone and FUSE system-wide and enables fuse user_allow_other, so a per-user rclone mount service can expose a cloud remote (e\.g\. Google Drive) under the configured mount point\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/rclone\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/rclone.nix)



## ft\.rclone\.mountPoint



Mount-point name a consumer’s per-user rclone mount service references (e\.g\. a home-manager systemd user service mounting under ~/\<mountPoint>)\. Convention only — this module does not create the mount itself\.



*Type:*
string



*Default:*

```nix
"GoogleDrive"
```



*Example:*

```nix
"GoogleDrive"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/rclone\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/rclone.nix)



## ft\.rclone\.remoteName



rclone remote name a consumer’s per-user mount service references (e\.g\. ` rclone mount <remoteName>: ... `)\. Convention only — this module does not create the mount itself\.



*Type:*
string



*Default:*

```nix
"gdrive"
```



*Example:*

```nix
"gdrive"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/rclone\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/rclone.nix)



## ft\.repoPath



Absolute path to the consumer’s flake repo root\. Set this in your host file\.



*Type:*
string



*Default:*

```nix
"/nix/ft-home"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/core\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/core.nix)



## ft\.sops\.enable



Wires up sops-nix pointing at ` ft.repoPath/var/secrets/secrets.yaml `, using the machine’s SSH host key for age decryption\. Enable ` ft.security.sops.useTPM ` or ` ft.security.sops.useYubikey ` for hardware-token decryption instead\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/sops\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/sops.nix)



## ft\.sops\.useTPM



Adds age-plugin-tpm, enables the TPM2 subsystem, and configures sops to read the age identity from /var/lib/sops-nix/key\.txt (populated by the TPM plugin)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/sops\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/sops.nix)



## ft\.sops\.useYubikey



Adds age-plugin-yubikey, starts pcscd for smart-card access, and configures sops to read the age identity stub from /var/lib/sops-nix/key\.txt (populated by the YubiKey plugin)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/sops\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/sops.nix)



## ft\.tailscale\.enable



Connects the machine to a Tailscale mesh network, trusts the tailscale0 interface in the firewall, and installs the Trayscale GUI tray app\. Set ` ft.tailscale.useRoutingFeatures = "server" ` to run as an exit node\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/tailscale\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/tailscale.nix)



## ft\.tailscale\.enableTrayApp



Enable Trayscale GUI tray application\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/tailscale\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/tailscale.nix)



## ft\.tailscale\.useRoutingFeatures



Tailscale routing features (client or server/exit node)\.



*Type:*
one of “client”, “server”



*Default:*

```nix
"client"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/tailscale\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/services/tailscale.nix)



## ft\.users\.enable



Creates and manages all system users: always creates an ` admin ` wheel user; additional wheel users from ` superUsers `; unprivileged users from ` normalUsers `\. All users get zsh and common group membership\.



*Type:*
boolean



*Default:*

```nix
true
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user.nix)



## ft\.users\.initialPasswords



Per-user initial plaintext passwords set at first boot\. Key is username; value overrides the ‘changeme’ default\. Use sops secrets for production credentials\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  admin = "mypassword";
  guest = "guestpass";
}
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user.nix)



## ft\.users\.mainUser



The primary username other modules (like Home Manager) will target\.



*Type:*
string



*Default:*

```nix
"admin"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user.nix)



## ft\.users\.normalUsers



Standard users with no administrative privileges\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user.nix)



## ft\.users\.superUsers



Extra users who get sudo (wheel) access\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user.nix)



## ft\.users\.u2f\.enable



Enables PAM U2F for login and sudo\. Configure per-user FIDO2 credentials via ` ft.users.u2f.mappings `\. ` nouserok ` is always set so users without a key entry fall through to password authentication\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user.nix)



## ft\.users\.u2f\.mappings



Per-user U2F key data\. Attribute name is the username; value is the raw credential string (the part after ‘username:’ in the pam-u2f authfile format)\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  admin = "publicKey,keyHandle";
  guest = "publicKey2,keyHandle2";
}
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/user.nix)



## ft\.vendorHw\.enable



Installs and configures vendor-specific drivers, daemons, and tooling based on hardware detected in facter\.json; covers Lenovo Legion, Razer, MSI, Logitech, Corsair, OpenRGB, ASUS ROG/TUF, and handheld gaming devices\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.asus



Override autodetect for asusctl (asusd daemon, fan curves, AuraSync) for ASUS ROG/TUF laptops\. Null uses autodetect via DMI manufacturer string\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.autodetect



Read ft\.facter\.reportPath and enable matching vendor tooling automatically\. Set to false to use only the per-brand override options below\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.corsair



Override autodetect for ckb-next Corsair keyboard/mouse driver and GUI\. Null uses autodetect via USB vendor ID 1b1c\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.handheld



Override autodetect for InputPlumber (OGC input remapping framework) and PowerStation (TDP and power-profile control) for handheld gaming devices (Legion Go, GPD, Ayaneo, AYN)\. Null uses autodetect via SMBIOS chassis type 11 or known DMI manufacturer strings\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.lenovo



Override autodetect for Lenovo Legion Linux (out-of-tree kernel driver and legiond daemon)\. Null uses autodetect via DMI manufacturer/family strings\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.logitech



Override autodetect for Solaar (Unifying/Bolt receivers) and Piper/ratbagd (gaming mice/keyboards)\. Null uses autodetect via USB vendor ID 046d\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.msi



Override autodetect for the msi-ec kernel module (mainlined since Linux 5\.16) and MControlCenter GUI\. Null uses autodetect via DMI manufacturer string\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.openrgb



Enable OpenRGB universal RGB lighting daemon and the i2c-dev kernel module it requires\. No facter autodetect — set true to enable explicitly\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.vendorHw\.razer



Override autodetect for OpenRazer kernel driver/daemon and Polychromatic GUI\. Null uses autodetect via USB vendor ID 1532\.



*Type:*
null or boolean



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/vendor-hw.nix)



## ft\.virt\.enable



Enables libvirtd/KVM with virt-manager and adds ` ft.users.mainUser ` to the libvirtd group\. Optionally enable ` ft.virt.enableVmwareHost ` for VMware Workstation, ` ft.virt.enableIncus ` for Incus containers, and ` ft.virt.enableSpiceUsbRedirection ` for USB passthrough to VMs\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt.nix)



## ft\.virt\.enableIncus



Enable Incus (LXD fork) container hypervisor\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt.nix)



## ft\.virt\.enableSpiceUsbRedirection



Enable SPICE USB redirection for VMs\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt.nix)



## ft\.virt\.enableVmwareHost



Enable VMware Workstation host support\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/system/virt.nix)



## ft\.wine\.enable



Installs Bottles, Wine (WOW64 build), and Winetricks for running Windows applications outside of Steam\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/wine\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/profiles/wine.nix)



## ft\.yubikey\.enable



Installs YubiKey management tools (yubikey-manager, yubico-piv-tool, pam_u2f), enables pcscd, and activates ` ft.users.u2f `\. Set per-user FIDO2 credentials via ` ft.users.u2f.mappings ` in your machine config\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/yubikey\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/nixos/hardware/yubikey.nix)


