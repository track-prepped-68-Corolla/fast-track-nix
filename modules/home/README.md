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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core.nix)



## ft\.core\.stateVersion



The Home Manager release version this user profile was *first created* on\. Controls which state migration paths activate — set it once at user creation and never change it\.



*Type:*
string

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core.nix)



## ft\.cosmic\.enable



Applies COSMIC-specific theming overrides on top of ` ft.theme `\. Enable this alongside ` ft.cosmic.enable ` (NixOS) when running the COSMIC desktop environment\.



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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/dotfiles\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/dotfiles.nix)



## ft\.dotfiles\.path



Absolute path to this user’s dotfiles directory\.



*Type:*
string



*Default:*

```nix
"/nix/ft-home/users/docs-eval/dotfiles"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core.nix)



## ft\.komodo\.enable



Deploys Komodo Core, Periphery, and PostgreSQL as rootless Podman user services via systemd\. Requires ft\.sops\.enable = true\. Populate the sops secret keys documented in NOTES\.md before first deploy\.



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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo.nix)



## ft\.komodo\.dataDir



Base directory for persistent Komodo container data (postgres, core)\.



*Type:*
string



*Default:*

```nix
"/home/docs-eval/.local/share/komodo"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo.nix)



## ft\.komodo\.images\.core



Komodo Core container image ref\. Override with an immutable digest to lock the version\.



*Type:*
string



*Default:*

```nix
"ghcr.io/moghtech/komodo/core:latest"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo.nix)



## ft\.komodo\.images\.periphery



Komodo Periphery container image ref\. Override with an immutable digest to lock the version\.



*Type:*
string



*Default:*

```nix
"ghcr.io/moghtech/komodo/periphery:latest"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo.nix)



## ft\.komodo\.images\.postgres



Postgres container image ref\. Override with an immutable digest to lock the version, e\.g\. docker\.io/library/postgres@sha256:\<digest>\.



*Type:*
string



*Default:*

```nix
"docker.io/library/postgres:16"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/komodo.nix)



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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/lazyvim\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/lazyvim.nix)



## ft\.repoPath



Absolute path to the consumer’s flake repo root\. Set in homes/\<username>/default\.nix\.



*Type:*
string



*Default:*

```nix
"/nix/ft-home"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/home-core.nix)



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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/sops\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/sops.nix)



## ft\.terminal\.enable



Deploys the full terminal stack: kitty and ghostty (terminals), zsh sourced from dotfiles, starship prompt, zoxide, fzf, and a curated set of CLI tools (bat, eza, btop, fd, ripgrep, yazi, lazygit, tealdeer, and more)\. Configs for starship and ghostty are wired as live out-of-store symlinks\.



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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/terminal\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/terminal.nix)



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
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.emoji\.package



This option has no description\.



*Type:*
package



*Default:*

```nix
<derivation noto-fonts-color-emoji-2.051>
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.emoji\.name



This option has no description\.



*Type:*
string



*Default:*

```nix
"Noto Color Emoji"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.mono\.package



This option has no description\.



*Type:*
package



*Default:*

```nix
<derivation nerd-fonts-atkynson-mono-3.4.0+2.001>
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.mono\.name



This option has no description\.



*Type:*
string



*Default:*

```nix
"AtkynsonMono Nerd Font Mono"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.sans\.package



This option has no description\.



*Type:*
package



*Default:*

```nix
<derivation atkinson-hyperlegible-0-unstable-2021-04-29>
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.sans\.name



This option has no description\.



*Type:*
string



*Default:*

```nix
"Atkinson Hyperlegible"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.serif\.package



This option has no description\.



*Type:*
package



*Default:*

```nix
<derivation ibm-plex-0-unstable-2026-02-12>
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.fonts\.serif\.name



This option has no description\.



*Type:*
string



*Default:*

```nix
"IBM Plex Serif"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.schemeName



Human-readable name of the scheme (used by COSMIC)\.



*Type:*
string



*Default:*

```nix
"Catppuccin Mocha"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.schemePath



Path to the Base16 YAML scheme\.



*Type:*
absolute path or string



*Default:*

```nix
"/nix/store/nybrx232xy4a2pqhskakkxgxfwjygxsy-base16-schemes-0-unstable-2026-01-15/share/themes/catppuccin-mocha.yaml"
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)



## ft\.theme\.wallpaper



Required: path to the primary desktop wallpaper\. Set this in your user config, e\.g\. ft\.theme\.wallpaper = \./wallpapers/default\.png;\. No framework default is provided because a framework-relative path would resolve into the framework repo, not the consumer’s\.



*Type:*
absolute path or string



*Example:*

```nix
./wallpapers/default.png
```

*Declared by:*
 - [/nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix\.nix](file:///nix/store/38bryrkrsn5w20ibk1siwglx95hajm22-source/modules/home/stylix.nix)


