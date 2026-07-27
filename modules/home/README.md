## ft\.atuin\.enable

Replaces zsh’s plain history search with atuin: a SQLite-backed, searchable shell history with a fuzzy TUI\. Local-only by default — no sync account or daemon\. Takes over Ctrl+R and the up-arrow key; if ft\.terminal’s fzf integration is also enabled, fzf’s Ctrl+T/Alt+C bindings are unaffected since atuin’s shell init runs after fzf’s and only rebinds Ctrl+R and up-arrow\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/atuin\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/atuin.nix)



## ft\.cli\.enable



Installs just and a thin ` ft ` wrapper that invokes the repo’s ` scripts/ft.just ` justfile from any working directory\. Home Manager counterpart of the NixOS ft\.cli module, independently useful on standalone Home Manager systems or non-NixOS distros (SteamOS, Bazzite)\. Requires ` ft.repoPath ` to point to your consumer repo root\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/cli\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/cli.nix)



## ft\.containers\.enable



Sets up a per-user (rootless) Docker or Podman runtime with the real Docker Compose v2 binary and optional Distrobox\. User-level apps like ft\.komodo build on top and reach the daemon via ft\.containers\.socket\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers.nix)



## ft\.containers\.compose\.enable



Install the genuine Docker Compose v2 binary (pkgs\.docker-compose) into the user profile\. podman-compose is never used\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers.nix)



## ft\.containers\.dataDir



Base directory for the user’s docker-compose and bind-mount workloads\.



*Type:*
string



*Default:*

```nix
"/home/docs-eval/.local/share/containers"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers.nix)



## ft\.containers\.distrobox\.enable



Install Distrobox into the user profile for running other-distribution containers as host-integrated environments\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers.nix)



## ft\.containers\.runtime



OCI runtime\. Podman runs natively per-user via a systemd --user socket; with docker, the user’s own rootless dockerd (set up outside Home Manager) is assumed\. Both expose a Docker-API-compatible socket the genuine docker-compose binary drives\.



*Type:*
one of “docker”, “podman”



*Default:*

```nix
"podman"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers.nix)



## ft\.containers\.socket



Read-only: the Docker-API-compatible user socket (systemd %t form) the runtime exposes\. Consumed by user-level apps built on this module (e\.g\. ft\.komodo) as DOCKER_HOST\.



*Type:*
string *(read only)*



*Default:*

```nix
"%t/podman/podman.sock"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/containers.nix)



## ft\.core\.enable



Activates the mandatory Home Manager foundation: sets stateVersion, homeDirectory, XDG base directories, genericLinux compatibility, and unfree packages\. Must remain enabled for all other home modules to function\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core.nix)



## ft\.core\.genericLinux



Enables Home Manager’s targets\.genericLinux, which sources HM session variables into shell profiles and installs the per-user Nix profile path (~/\.local/state/nix/profiles/home-path)\. Required for standalone Home Manager on non-NixOS Linux (Ubuntu, Fedora, etc\.)\. Must be false when HM is used as a NixOS module (home-manager\.nixosModules\.home-manager): the install_profile activation step will fail because ~/\.local/state/nix/profiles does not exist on a freshly-booted NixOS system\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core.nix)



## ft\.core\.stateVersion



The Home Manager release version this user profile was *first created* on\. Controls which state migration paths activate — set it once at user creation and never change it\.



*Type:*
string

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core.nix)



## ft\.dotfiles\.enable



Recursively symlinks every file under ` ft.dotfiles.path ` into Home Manager’s home\.file set using out-of-store symlinks, so dotfiles stay live-editable without a rebuild\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/dotfiles\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/dotfiles.nix)



## ft\.dotfiles\.path



Absolute path to this user’s dotfiles directory\.



*Type:*
string



*Default:*

```nix
"/nix/ft-home/users/docs-eval/dotfiles"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core.nix)



## ft\.flatpak\.enable



Registers the Flathub remote for this user’s ` --user ` Flatpak installs and exposes ` services.flatpak.packages ` (nix-flatpak) as the per-user declarative app list — set it in this user’s base config or any of their ` profiles/<name>/ ` submodules; the lists from every definition are merged\. Requires the host’s ` ft.flatpak.enable ` (NixOS) so the Flatpak service and desktop portal are present\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/flatpak\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/flatpak.nix)



## ft\.gaming\.enable



Installs MangoHud, ProtonUp-Qt, SteamTinkerLaunch, Goverlay, Heroic, steam-tui, steamcmd, and steam-run into the user profile\. Home Manager counterpart of the NixOS ft\.gaming module’s package set, independently useful on gaming-focused distros that already provide Steam (SteamOS, Bazzite) — Steam, GameMode, and gamescope remain NixOS-only since they require system-level privileges\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gaming\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gaming.nix)



## ft\.gitWorkflow\.enable



Installs conform, convco, and lefthook; registers global git hooks via core\.hooksPath that run treefmt format-checking and trufflehog secret scanning on pre-commit, and enforce conventional commit format on commit-msg\. The prepare-commit-msg hook appends NixOS generation metadata written by the ft switch recipe\. Enables the convco interactive commit builder\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/git-workflow\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/git-workflow.nix)



## ft\.gitWorkflow\.types



Allowed conventional commit types\. The commit-msg hook rejects messages whose type is not in this list\.



*Type:*
list of string



*Default:*

```nix
[
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
]
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/git-workflow\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/git-workflow.nix)



## ft\.gitops\.enable



Runs a daemon that clones/pulls remote\.url, and on a new commit on remote\.branch runs ` home-manager switch ` against homeConfigurations\.\<flakeAttr>, retrying a failing commit up to retry\.maxAttempts times before giving up on it until a new commit is pushed\. A from-scratch equivalent of the NixOS side’s comin-based ft\.gitops, since comin has no concept of Home Manager\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.gitops\.flakeAttr



The homeConfigurations\.\<flakeAttr> attribute to switch to, e\.g\. “alice@x86_64-linux”\.



*Type:*
string

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.gitops\.pollPeriod



How often, in seconds, this daemon polls remote\.url for new commits\.



*Type:*
signed integer



*Default:*

```nix
60
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.gitops\.remote\.branch



Branch this daemon tracks and deploys\.



*Type:*
string



*Default:*

```nix
"main"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.gitops\.remote\.url



Git URL this daemon clones/pulls\.



*Type:*
string

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.gitops\.repoPath



Local path this daemon clones/pulls the repository into\. Its own private checkout, independent of any NixOS ft\.repoPath, since standalone Home Manager may run on a non-NixOS host\.



*Type:*
string

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.gitops\.retry\.maxAttempts



Consecutive failed switch attempts on the same commit before giving up on it until a new commit is pushed\. Uses pollPeriod as the retry cadence\.



*Type:*
signed integer



*Default:*

```nix
3
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.gitops\.signingKeys



Armored GPG public key files; a commit is only switched to if it is signed by one of these\. An empty list disables signature verification, letting any commit on remote\.branch deploy unattended — strongly discouraged outside testing\.



*Type:*
list of absolute path



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/gitops.nix)



## ft\.karousel\.enable



Installs the Karousel KWin script and enables it via kwinrc\. Requires ` ft.plasmaManager.enable ` so the kwinrc Plugins key is managed declaratively\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/karousel\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/karousel.nix)



## ft\.komodo\.enable



Deploys the upstream Komodo compose stack (Core, Periphery, FerretDB/Postgres) as a user-level docker-compose service on top of the Home Manager ft\.containers\. Requires ft\.containers\.enable with compose\.enable\. Exempt from VM smoke tests: pulls images from ghcr\.io at runtime\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.adminPassword



Default initial Komodo admin password, used only when ft\.komodo\.sopsEnv\.enable is false (written to the Nix store — local-only)\. With sopsEnv on, KOMODO_INIT_ADMIN_PASSWORD from the sops env-file overrides it\.



*Type:*
string



*Default:*

```nix
"admin"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.adminUsername



Initial Komodo admin username created on first launch (not a secret)\.



*Type:*
string



*Default:*

```nix
"admin"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.autoApply\.enable



After Komodo Core answers, run the bundled ` komodo-apply ` recipe from ft\.repoPath to reconcile Komodo with the consumer repo’s containers/ directory over Komodo’s API, with no UI\. Runs as a user systemd oneshot\. Requires ft\.cli, ft\.sops and ft\.repoPath, plus a user sops secret (autoApply\.apiEnvSecret) holding KOMODO_API_KEY and KOMODO_API_SECRET\. Exempt from VM smoke tests: reconciles against a live Komodo API\. See NOTES\.md\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.autoApply\.apiEnvSecret



User sops secret key holding an env-file with KOMODO_API_KEY and KOMODO_API_SECRET (create a Komodo API key once)\. Declared and read by the auto-apply user service to authenticate to Komodo’s API\.



*Type:*
string



*Default:*

```nix
"komodo/api_env"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.backupsPath



Path where Komodo Core writes backup archives, bind-mounted into the Core container at /backups\.



*Type:*
string



*Default:*

```nix
"/home/docs-eval/.local/share/komodo/backups"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.dataDir



Base directory for the Komodo compose project (compose files, credentials env-file, logs) and the default backups/periphery trees\.



*Type:*
string



*Default:*

```nix
"/home/docs-eval/.local/share/komodo"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.dbPassword



Default password for the FerretDB/Postgres database, used only when ft\.komodo\.sopsEnv\.enable is false (written to the Nix store — local-only)\. With sopsEnv on, KOMODO_DATABASE_PASSWORD from the sops env-file overrides it\.



*Type:*
string



*Default:*

```nix
"komodo"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.dbUsername



Username for the FerretDB/Postgres database (not a secret — baked into the compose config)\.



*Type:*
string



*Default:*

```nix
"komodo"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.host



Externally accessible URL for the Komodo Core instance; used for OAuth redirect URLs and webhook suggestions\.



*Type:*
string



*Default:*

```nix
"http://localhost:9120"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.imageTag



Docker image tag for ghcr\.io/moghtech/komodo-core and komodo-periphery\.



*Type:*
string



*Default:*

```nix
"latest"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.includeDiskMounts



Mount points Periphery reports disk usage for in the Komodo UI (PERIPHERY_INCLUDE_DISK_MOUNTS)\. An empty list omits the setting so Periphery reports every detected mount\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.jwtSecret



Default secret for signing Komodo JWT tokens, used only when ft\.komodo\.sopsEnv\.enable is false (written to the Nix store)\. With sopsEnv on, KOMODO_JWT_SECRET from the sops env-file overrides it\.



*Type:*
string



*Default:*

```nix
"komodo-jwt-secret"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.peripheryRootDirectory



Periphery’s root directory (PERIPHERY_ROOT_DIRECTORY), bind-mounted into the periphery container at the same path\. Every stack Periphery deploys and the source side of every bind mount it manages live under this directory\.



*Type:*
string



*Default:*

```nix
"/home/docs-eval/.local/share/komodo/periphery"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.repoCachePath



Path bind-mounted into Komodo Core at /repo-cache, where it clones git repos for repo-based Stacks and Resource Syncs\. null leaves the clones on the container’s ephemeral layer\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.secrets\.core\.enable



Declares the komodo/core_secrets user sops key, mounts it read-only into the Core container, and loads it via ` core --config-path `\. Its keys become globally \[\[KEY]]-interpolatable into every Stack/Deployment\. This is for interpolation into deployed Stacks — distinct from ft\.komodo\.sopsEnv, which covers Komodo’s own credentials\. Requires a configured sops-nix (normally ft\.sops\.enable)\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.secrets\.periphery\.enable



Declares the komodo/periphery_secrets user sops key, mounts it read-only into the Periphery container, and loads it via ` periphery --config-path `\. Its keys become \[\[KEY]]-interpolatable into the Stacks this Periphery deploys and are hidden from the Komodo UI and logs\. This is for interpolation into deployed Stacks — distinct from ft\.komodo\.sopsEnv, which covers Komodo’s own credentials\. Requires a configured sops-nix (normally ft\.sops\.enable)\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.serverName



Name for the first Komodo server entry, and the name Periphery uses when connecting to Core\.



*Type:*
string



*Default:*

```nix
"Local"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.sopsEnv\.enable



Sources the sensitive Komodo credentials (KOMODO_DATABASE_PASSWORD, KOMODO_INIT_ADMIN_PASSWORD, KOMODO_JWT_SECRET, KOMODO_WEBHOOK_SECRET) from a user-level sops-decrypted env-file (ft\.komodo\.sopsEnv\.secretName) instead of the Nix store\. Requires a configured sops-nix (normally ft\.sops\.enable); populate the key as KEY=VALUE lines — see NOTES\.md\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.sopsEnv\.secretName



User sops secret key holding the Komodo credentials as an env-file (KEY=VALUE lines)\. Declared and decrypted when sopsEnv\.enable is true\.



*Type:*
string



*Default:*

```nix
"komodo/env"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.syncPath



Path bind-mounted into Komodo Core at /syncs, used for ‘Files on Server’ Resource Syncs\. null leaves the files on the container’s ephemeral layer\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.timezone



Timezone for Komodo schedules (tz database name, e\.g\. America/New_York)\.



*Type:*
string



*Default:*

```nix
"Etc/UTC"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.komodo\.webhookSecret



Default secret for authenticating incoming Komodo webhooks, used only when ft\.komodo\.sopsEnv\.enable is false (written to the Nix store)\. With sopsEnv on, KOMODO_WEBHOOK_SECRET from the sops env-file overrides it\.



*Type:*
string



*Default:*

```nix
"komodo-webhook-secret"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/komodo.nix)



## ft\.lazyvim\.enable



Installs Neovim with a full suite of language servers and dev tools for Python, Go, Rust, Nix, and web development\. Symlinks ` ft.dotfiles.path/nvim ` into XDG config as a live out-of-store link and sets EDITOR/VISUAL to nvim\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/lazyvim\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/lazyvim.nix)



## ft\.mullet\.enable



Installs every package named in the newline-delimited file at ` ft.mullet.sourcePath ` into home\.packages\. Lets a consumer add or remove user-scoped packages by editing a plain text file instead of editing Nix\. Unresolved names are silently skipped\. Home Manager counterpart of the NixOS ft\.mullet module\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/mullet\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/mullet.nix)



## ft\.mullet\.sourcePath



Flake-relative path to the flat newline-delimited text file tracking imperatively-managed package attribute names for this user\. When this home configuration was generated via ft-home\.lib\.mkFlake, defaults to var/mullet\.txt inside this user’s own users/\<username>/ directory\. Set explicitly to override that location, or if this module is used via homeManagerModules\.default outside the generator (where no default is available)\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
./var/mullet-custom.txt
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/mullet\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/mullet.nix)



## ft\.nixIndex\.enable



Installs nix-index with a pre-built database and comma into the user profile\. Home Manager counterpart of the NixOS ft\.nixIndex module, independently useful on standalone Home Manager systems or non-NixOS distros (SteamOS, Bazzite)\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/nix-index\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/nix-index.nix)



## ft\.nixIndex\.comma



Enable comma — run uninstalled commands via nix-index\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/nix-index\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/nix-index.nix)



## ft\.plasmaManager\.enable



Enables plasma-manager so KDE Plasma settings (panels, shortcuts, kwinrc keys, etc\.) are declared in Home Manager via ` programs.plasma.* ` instead of mutated through the Plasma GUI\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/plasma-manager\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/plasma-manager.nix)



## ft\.rclone\.enable



Runs a systemd user service that mounts an rclone remote at a path under $HOME via FUSE\. Home Manager counterpart of the NixOS ft\.rclone module, which installs rclone/FUSE system-wide and enables fuse user_allow_other; this module owns the actual per-user mount unit\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone.nix)



## ft\.rclone\.extraMountArgs



Extra arguments passed to ` rclone mount `, appended after the remote and mount-point arguments (e\.g\. cache mode, buffer size)\.



*Type:*
list of string



*Default:*

```nix
[
  "--vfs-cache-mode"
  "writes"
]
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone.nix)



## ft\.rclone\.mountPoint



Directory name under $HOME where the remote is mounted (e\.g\. ~/GoogleDrive)\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone.nix)



## ft\.rclone\.remoteName



rclone remote name to mount, as configured in this user’s rclone config (e\.g\. via ` rclone config `)\. Must match an existing remote\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/rclone.nix)



## ft\.repoPath



Absolute path to the consumer’s flake repo root\. Set in homes/\<username>/default\.nix\.



*Type:*
string



*Default:*

```nix
"/nix/ft-home"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/home-core.nix)



## ft\.sops\.enable



Configures sops-nix for this user, pointing the age key at ~/\.config/sops/age/keys\.txt and the secrets file at the user’s var/secrets\.yaml in the consumer repo\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/sops\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/sops.nix)



## ft\.steamConfig\.enable



Enables steam-config-nix, which declaratively manages Steam launch options, per-game compatibility-tool overrides, and non-Steam game shortcuts\. Configure individual games under programs\.steam\.config\.apps and programs\.steam\.config\.nonSteamApps once enabled\. Home Manager counterpart of the NixOS ft\.steamConfig module — use on standalone Home Manager systems or non-NixOS distros\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/steam-config\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/steam-config.nix)



## ft\.terminal\.enable



Deploys the full terminal stack: ghostty (terminal), zsh sourced from dotfiles with lazily-loaded plugin support, starship prompt, zoxide, fzf, and a curated set of CLI tools (bat, eza, btop, fd, ripgrep, yazi, lazygit, tealdeer, and more)\. Configs for starship and ghostty are wired as live out-of-store symlinks\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal.nix)



## ft\.terminal\.zshPlugins\.autosuggestions\.enable



Enable zsh-autosuggestions, suggesting commands as you type based on history\. Sourced via zsh-defer so it doesn’t block shell startup\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal.nix)



## ft\.terminal\.zshPlugins\.commaAssistant\.enable



Enable zsh-comma-assistant: friendlier command-not-found handling (offers to run unknown commands via comma) and, when zshPlugins\.syntaxHighlighting is also enabled, highlights commands available via comma/nix-index\. Requires ft\.nixIndex\.enable for the comma binary and database; no-ops if that’s disabled\. Sourced via zsh-defer so it doesn’t block shell startup\. NOTE: currently defaults off — the pinned fetchFromGitHub source uses a placeholder hash pending a real one\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal.nix)



## ft\.terminal\.zshPlugins\.completions\.enable



Enable zsh-completions, a collection of additional completion definitions\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal.nix)



## ft\.terminal\.zshPlugins\.syntaxHighlighting\.enable



Enable zsh-syntax-highlighting, highlighting commands as they are typed\. Sourced via zsh-defer so it doesn’t block shell startup\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/terminal.nix)



## ft\.theme\.enable



Applies a Catppuccin Mocha theme system-wide via Stylix: configures fonts (Atkinson Hyperlegible, AtkynsonMono Nerd Font, IBM Plex Serif), catppuccin-mocha-dark cursor, window and terminal opacity, and wallpaper\. Override defaults with ` ft.theme.wallpaper `, ` ft.theme.schemePath `, and ` ft.theme.fonts.* `\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.emoji\.package



Package providing the emoji font\.



*Type:*
package



*Default:*

```nix
<derivation noto-fonts-color-emoji-2.051>
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.emoji\.name



Font family name for the emoji role\.



*Type:*
string



*Default:*

```nix
"Noto Color Emoji"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.mono\.package



Package providing the monospace font\.



*Type:*
package



*Default:*

```nix
<derivation nerd-fonts-atkynson-mono-3.4.0+2.001>
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.mono\.name



Font family name for the monospace role\.



*Type:*
string



*Default:*

```nix
"AtkynsonMono Nerd Font Mono"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.sans\.package



Package providing the sans-serif font\.



*Type:*
package



*Default:*

```nix
<derivation atkinson-hyperlegible-0-unstable-2021-04-29>
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.sans\.name



Font family name for the sans-serif role\.



*Type:*
string



*Default:*

```nix
"Atkinson Hyperlegible"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.serif\.package



Package providing the serif font\.



*Type:*
package



*Default:*

```nix
<derivation ibm-plex-0-unstable-2026-05-26>
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.serif\.name



Font family name for the serif role\.



*Type:*
string



*Default:*

```nix
"IBM Plex Serif"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.schemeName



Human-readable name of the scheme\.



*Type:*
string



*Default:*

```nix
"Catppuccin Mocha"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.schemePath



Path to the Base16 YAML scheme\.



*Type:*
absolute path or string



*Default:*

```nix
"/nix/store/6b8y0g0vyz2lh84rn4mscvhlwzgga6ql-base16-schemes-0-unstable-2026-01-15/share/themes/catppuccin-mocha.yaml"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.theme\.wallpaper



Required: path to the primary desktop wallpaper\. Set this in your user config, e\.g\. ft\.theme\.wallpaper = \./wallpapers/default\.png;\. No framework default is provided because a framework-relative path would resolve into the framework repo, not the consumer’s\.



*Type:*
absolute path or string



*Example:*

```nix
./wallpapers/default.png
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/stylix.nix)



## ft\.vicinae\.enable



Installs and runs the Vicinae launcher (app search, clipboard history, emoji picker, calculator, Raycast-compatible extensions) as a systemd user service\. Exposes ` programs.vicinae.{extensions,themes,settings} ` (vicinae’s own module) as the configuration surface — set those directly in this user’s config\. Pair with the host’s ` ft.vicinae.inputServer.enable ` (NixOS) for global-hotkey and keystroke-injection support\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/vicinae\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/vicinae.nix)



## ft\.webapps\.enable



Generates application-launcher entries that open arbitrary websites as standalone, app-style windows (no address bar or tabs) using a Chromium-family browser’s --app= mode, each in its own isolated profile directory\. A lightweight alternative to bundling a full Electron/nativefier wrapper per site\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.webapps\.apps



Set of website-backed apps to expose as desktop launchers, keyed by a short app id used for the isolated profile directory and window class\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.webapps\.apps\.\<name>\.browser



Per-app override of the Chromium-family browser used to launch this webapp\. Falls back to ft\.webapps\.browser when null\.



*Type:*
null or one of “chromium”, “google-chrome”, “brave”, “vivaldi”, “ungoogled-chromium”



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.webapps\.apps\.\<name>\.categories



Freedesktop desktop-entry categories used to place this webapp in application menus\.



*Type:*
list of string



*Default:*

```nix
[
  "Network"
]
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.webapps\.apps\.\<name>\.icon



Path to a local icon image\. When null, the site’s favicon is fetched automatically at Home Manager activation time (best-effort; silently keeps the browser’s default icon if the fetch is unavailable, e\.g\. offline)\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.webapps\.apps\.\<name>\.name



Display name shown in the application launcher\.



*Type:*
string

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.webapps\.apps\.\<name>\.url



URL the webapp window opens to\.



*Type:*
string

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.webapps\.browser



Default Chromium-family browser used to launch webapps in --app= mode\. Only Chromium-family browsers support --app=; Firefox has no equivalent without the separate PWAsForFirefox stack, so it is not offered here\.



*Type:*
one of “chromium”, “google-chrome”, “brave”, “vivaldi”, “ungoogled-chromium”



*Default:*

```nix
"chromium"
```

*Declared by:*
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/webapps.nix)



## ft\.wine\.enable



Installs Bottles, Wine (WOW64 build), and Winetricks into the user profile for running Windows applications outside of Steam\. Home Manager counterpart of the NixOS ft\.wine module — use on standalone Home Manager systems or non-NixOS distros\.



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
 - [/nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/wine\.nix](file:///nix/store/2zy18yggdmwlr4kbs2gd8q06ghwk1wfj-source/modules/home/wine.nix)


