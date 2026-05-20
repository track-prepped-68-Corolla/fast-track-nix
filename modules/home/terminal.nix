{
  config,
  pkgs,
  lib,
  ...
}:

################################################################################
# TERMINAL & SHELL MODULE
# ------------------------------------------------------------------------------
# "Batteries Included" Terminal.
################################################################################

let
  cfg = config.ft.terminal;
in
{
  options.ft.terminal.enable = lib.mkEnableOption "terminal stack" // {
    default = true;
    description = "Deploys the full terminal stack: kitty and ghostty (terminals), zsh sourced from dotfiles, starship prompt, zoxide, fzf, and a curated set of CLI tools (bat, eza, btop, fd, ripgrep, yazi, lazygit, tealdeer, and more). Configs for starship and ghostty are wired as live out-of-store symlinks.";
  };

  config = lib.mkIf cfg.enable {
    home = {
      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      packages = with pkgs; [
        git
        curl
        wget
        gnutar
        gzip
        unzip
        zip
        psmisc
        which
        tree
        fastfetch
        cpufetch
        ghostty
        kitty
        neovim
        bat
        eza
        btop
        fd
        ripgrep
        dust
        yazi
        lazygit
        tealdeer
        jq
        gping
        browsh
        ddgr
      ];

      file = {
        ".config/starship.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${config.ft.dotfiles.path}/starship/starship.toml";
        ".config/ghostty/config".source =
          config.lib.file.mkOutOfStoreSymlink "${config.ft.dotfiles.path}/ghostty/config";
      };
    };

    programs = {
      kitty = {
        enable = true;
        settings = {
          scrollback_lines = 10000;
          enable_audio_bell = false;
          update_check_interval = 0;
          window_padding_width = 4;
        };
      };

      zsh = {
        enable = true;
        dotDir = "${config.xdg.configHome}/zsh";
        enableCompletion = true;
        initContent = "source ${config.ft.dotfiles.path}/zsh/.zshrc";
      };

      starship = {
        enable = true;
        enableZshIntegration = true;
      };

      zoxide = {
        enable = true;
        enableZshIntegration = true;
      };

      fzf = {
        enable = true;
        enableZshIntegration = true;
      };
    };
  };
}
