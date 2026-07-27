{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ft.lazyvim;
in
{
  options.ft.lazyvim = {
    enable = lib.mkEnableOption "Custom LazyVim configuration" // {
      description = "Installs Neovim along with a full set of language servers and development tools for Python, Go, Rust, Nix, and web development. It symlinks `ft.dotfiles.path/nvim` into your XDG config as a live, editable link, and sets `EDITOR`/`VISUAL` to `nvim`.";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
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

      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    };

    xdg.configFile."nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${config.ft.dotfiles.path}/nvim";
  };
}
