{ config, pkgs, lib, ... }:

let
  cfg = config.ft.lazyvim;
in
{
  options.ft.lazyvim = {
    enable = lib.mkEnableOption "Custom LazyVim configuration" // {
      description = "Installs Neovim with a full suite of language servers and dev tools for Python, Go, Rust, Nix, and web development. Symlinks `ft.dotfiles.path/nvim` into XDG config as a live out-of-store link and sets EDITOR/VISUAL to nvim.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      neovim
      git
      gcc
      gnumake
      ripgrep
      fd
      lazygit
      unzip
      wget
      curl
      tree-sitter
      nodejs
      wl-clipboard
      pyright
      black
      isort
      go
      gopls
      gofumpt
      cargo
      rustc
      rust-analyzer
      rustfmt
      clang-tools
      marksman
      prettier
      yaml-language-server
      vscode-langservers-extracted
      lemminx
      nixd
      nixfmt
    ];

    xdg.configFile."nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${config.ft.dotfiles.path}/nvim";

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
