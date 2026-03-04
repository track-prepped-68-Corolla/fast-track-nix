{ pkgs, ... }:

################################################################################
# TERMINAL & SHELL MODULE
# ------------------------------------------------------------------------------
# "Batteries Included" Terminal.
# THE PHILOSOPHY:
# We use Neovim as the default editor, but we inject "Normie Bindings" (Ctrl+S/C/V)
# via Lua so beginners can edit files without panicking.
################################################################################

{
  # ----------------------------------------------------------------------------
  # 1. ENVIRONMENT VARIABLES
  # ----------------------------------------------------------------------------
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # ----------------------------------------------------------------------------
  # 2. THE TERMINAL: Kitty
  # ----------------------------------------------------------------------------
  programs.kitty = {
    enable = true;
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
      window_padding_width = 4;
    };
  };

  # ----------------------------------------------------------------------------
  # 3. THE SHELL: Zsh
  # ----------------------------------------------------------------------------
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch = {
      enable = true;
    };

    shellAliases = {
      # Redirect 'vim' to our customized nvim
      vim = "nvim";
      vi = "nvim";
      edit = "nvim";

      # Modern Core
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first";
      cat = "bat";
      top = "btop";
      cd = "z";

      # Shortcuts
      lg = "lazygit";
      ra = "yazi";
      fetch = "fastfetch";
      internet = "browsh";
    };
  };

  # ----------------------------------------------------------------------------
  # 5. SUPPORTING PACKAGES
  # ----------------------------------------------------------------------------
  home.packages = with pkgs; [
    # Foundation
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
    # System Info
    fastfetch
    cpufetch
    # Modern Core
    kitty
    neovim
    bat
    eza
    btop
    fd
    ripgrep
    dust
    # Workflow
    yazi
    lazygit
    tealdeer
    jq
    gping
    # Internet
    browsh
    ddgr
  ];

  # ----------------------------------------------------------------------------
  # 6. TMUX (Vim Integration)
  # ----------------------------------------------------------------------------
  programs.tmux = {
    enable = true;
    mouse = true;
    historyLimit = 50000;
    baseIndex = 1;
    plugins = with pkgs; [
      { plugin = tmuxPlugins.vim-tmux-navigator; }
      {
        plugin = tmuxPlugins.catppuccin;
        extraConfig = "set -g @catppuccin_flavour 'mocha'";
      }
    ];
    extraConfig = ''
      set -g default-terminal "screen-256color"
      bind -n M-H previous-window
      bind -n M-L next-window
    '';
  };

  # ----------------------------------------------------------------------------
  # 7. SHELL INTEGRATIONS
  # ----------------------------------------------------------------------------
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
