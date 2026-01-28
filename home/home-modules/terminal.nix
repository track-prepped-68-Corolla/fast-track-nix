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
      scrollback_lines      = 10000;
      enable_audio_bell     = false;
      update_check_interval = 0;
      window_padding_width  = 4;
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
    historySubstringSearch = { enable = true; };

    shellAliases = {
      # Redirect 'vim' to our customized nvim
      vim  = "nvim";
      vi   = "nvim";
      edit = "nvim";
      
      # Modern Core
      ls  = "eza --icons --group-directories-first";
      ll  = "eza -l --icons --group-directories-first";
      cat = "bat";
      top = "btop";
      cd  = "z";
      
      # Shortcuts
      lg       = "lazygit";
      ra       = "yazi"; 
      fetch    = "fastfetch";
      internet = "browsh";
    };
  };

  # ----------------------------------------------------------------------------
  # 4. NEOVIM (The "Sneak" Configuration)
  # ----------------------------------------------------------------------------
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    
    # We include these so the clipboard works and LazyVim can build later
    extraPackages = with pkgs; [
      gcc gnumake unzip nodejs_22 luajit xclip ripgrep fd
    ];

    # This LUA config injects the "Notepad Behavior" into Vim
    extraLuaConfig = ''
      -- 1. MOUSE SUPPORT (Click to move cursor, scroll wheel works)
      vim.opt.mouse = "a"

      -- 2. SYSTEM CLIPBOARD (Make Ctrl+C/V actually work outside terminal)
      -- Requires 'xclip' or 'wl-clipboard' (installed via extraPackages)
      vim.opt.clipboard = "unnamedplus"

      -- 3. THE "SNEAK" KEYBINDINGS
      local map = vim.keymap.set
      local opt = { noremap = true, silent = true }

      -- Ctrl+S to Save (Works in Normal, Insert, and Visual modes)
      map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", opt)

      -- Ctrl+Q to Quit (Works in all modes - Force Quits all buffers)
      map({ "n", "i", "v" }, "<C-q>", "<cmd>qa!<cr>", opt)

      -- Ctrl+Z to Undo (Standard behavior)
      map({ "n", "i" }, "<C-z>", "<cmd>u<cr>", opt)
      
      -- Ctrl+Y to Redo
      map({ "n", "i" }, "<C-y>", "<cmd>redo<cr>", opt)

      -- Ctrl+A to Select All
      map({ "n", "i" }, "<C-a>", "<esc>ggVG", opt)

      -- 4. COPY/PASTE BEHAVIOR
      -- Ctrl+C in Visual Mode = Copy to System Clipboard
      map("v", "<C-c>", '"+y', opt)
      
      -- Ctrl+V in Normal/Visual = Paste from System Clipboard
      map({ "n", "v" }, "<C-v>", '"+p', opt)
      
      -- Ctrl+V in Insert Mode = Paste from System Clipboard (Magic!)
      map("i", "<C-v>", '<C-r>+', opt)

      -- 5. SANITY SETTINGS
      vim.opt.number = true         -- Show line numbers
      vim.opt.relativenumber = true -- Show relative numbers (Good for jumping)
      vim.opt.ignorecase = true     -- Case insensitive search
      vim.opt.smartcase = true      -- ...unless you type a capital
    '';
  };

  # ----------------------------------------------------------------------------
  # 5. SUPPORTING PACKAGES
  # ----------------------------------------------------------------------------
  home.packages = with pkgs; [
    # Foundation
    git curl wget gnutar gzip unzip zip psmisc which tree
    
    # System Info
    fastfetch cpufetch

    # Modern Core
    bat eza btop fd ripgrep du-dust
    
    # Workflow
    yazi lazygit tealdeer jq gping
    
    # Internet
    browsh ddgr
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
  programs.zoxide = { enable = true; enableZshIntegration = true; };
  programs.fzf    = { enable = true; enableZshIntegration = true; };
  programs.starship = { enable = true; enableZshIntegration = true; };
}