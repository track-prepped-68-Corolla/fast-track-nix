# ft-home

A Nix flake framework that auto-discovers your hosts and homes so your personal
config stays minimal.

## How it works

ft-home uses a dual-repo architecture:

| Repo | Role |
|------|------|
| **ft-home** (this repo) | Framework: generator, shared modules, all flake inputs |
| **your-config** | Consumer: hosts, homes, your modules |

Your consumer `flake.nix` is intentionally minimal:

```nix
{
  inputs = {
    ft-home.url = "github:track-prepped-68-corolla/ft-home";
    nixpkgs.follows = "ft-home/nixpkgs";
    home-manager.follows = "ft-home/home-manager";
  };
  outputs = inputs @ { ft-home, ... }:
    ft-home.lib.mkFlake inputs;
}
```

## Auto-discovery

`lib/generator.nix` scans your consumer repo at evaluation time and builds flake
outputs automatically:

| Directory | Output |
|-----------|--------|
| `hosts/<arch>/<hostname>/` | `nixosConfigurations.<hostname>` |
| `hosts/<arch>-darwin/<hostname>/` | `darwinConfigurations.<hostname>` |
| `homes/<username>/` | `homeConfigurations.<username>@<arch>` for every discovered arch |

Dropping a `.nix` file under `modules/nixos/` or `modules/home/` in either
repo is sufficient — no `imports` list to maintain.

## Consumer directory layout

```
your-config/
  flake.nix
  hosts/
    x86_64-linux/
      mymachine/
        default.nix
        hardware-configuration.nix
  homes/
    alice/
      default.nix
  modules/
    nixos/          # auto-imported NixOS modules
    home/           # auto-imported home-manager modules
```

## ft.* options

Framework features are enabled with `ft.*` options in your host and home files:

```nix
# hosts/.../default.nix
{
  ft.kernel.cachyos.enable = true;
  ft.theme.enable = true;
}

# homes/.../default.nix
{
  ft.lazyvim.enable = true;
  ft.dotfiles = {
    enable = true;
    repoPath = "/home/alice/git/dotfiles";
  };
}
```

## Updating

```bash
nix flake update ft-home
```

Do not run `nix flake update nixpkgs` in your consumer — nixpkgs follows
ft-home's pin and has no standalone input node.

## Development

```bash
just fmt     # format all .nix files (nixfmt + deadnix via treefmt, then statix fix)
just check   # fmt + secret scan
just switch  # check + build + switch + commit
```
