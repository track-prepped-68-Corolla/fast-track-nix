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
  options.ft.terminal = {
    enable = lib.mkEnableOption "terminal stack" // {
      default = true;
      description = "Deploys the full terminal stack: ghostty (terminal), zsh sourced from dotfiles with plugin support, starship prompt, zoxide, fzf, and a curated set of CLI tools (bat, eza, btop, fd, ripgrep, yazi, lazygit, tealdeer, and more). Configs for starship and ghostty are wired as live out-of-store symlinks.";
    };

    zshPlugins = {
      autosuggestions.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable zsh-autosuggestions, suggesting commands as you type based on history.";
      };
      syntaxHighlighting.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable zsh-syntax-highlighting, highlighting commands as they are typed.";
      };
      completions.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable zsh-completions, a collection of additional completion definitions.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      sessionVariables = {
        EDITOR = lib.mkDefault "nvim";
        VISUAL = lib.mkDefault "nvim";
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
      zsh = {
        enable = true;
        dotDir = lib.mkDefault "${config.xdg.configHome}/zsh";
        enableCompletion = lib.mkDefault true;
        initContent = lib.mkDefault "source ${config.ft.dotfiles.path}/zsh/.zshrc";

        history = {
          size = lib.mkDefault 10000;
          save = lib.mkDefault 10000;
          ignoreDups = lib.mkDefault true;
          extended = lib.mkDefault true;
        };

        autosuggestion.enable = lib.mkDefault cfg.zshPlugins.autosuggestions.enable;
        syntaxHighlighting.enable = lib.mkDefault cfg.zshPlugins.syntaxHighlighting.enable;

        plugins = lib.optional cfg.zshPlugins.completions.enable {
          name = "zsh-completions";
          src = pkgs.zsh-completions;
        };
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
