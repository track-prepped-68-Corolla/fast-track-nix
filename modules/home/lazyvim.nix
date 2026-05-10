{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.ft.lazyvim;
  nvimConfigPath = "${config.ft.repoPath}/homes/${config.home.username}/dotfiles/nvim";
in
{
  options.ft.lazyvim = {
    enable = lib.mkEnableOption "Custom LazyVim configuration";
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
      config.lib.file.mkOutOfStoreSymlink nvimConfigPath;

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
