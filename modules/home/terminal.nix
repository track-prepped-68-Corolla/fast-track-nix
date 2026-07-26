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

  # Not in nixpkgs; pinned to a specific commit for reproducibility.
  commaAssistantSrc = pkgs.fetchFromGitHub {
    owner = "thesola10";
    repo = "zsh-comma-assistant";
    rev = "0b641292b345e24161ed79d5d22a9091a3841545";
    hash = lib.fakeHash;
  };
in
{
  options.ft.terminal = {
    enable = lib.mkEnableOption "terminal stack" // {
      default = true;
      description = "Deploys the full terminal stack: ghostty (terminal), zsh sourced from dotfiles with lazily-loaded plugin support, starship prompt, zoxide, fzf, and a curated set of CLI tools (bat, eza, btop, fd, ripgrep, yazi, lazygit, tealdeer, and more). Configs for starship and ghostty are wired as live out-of-store symlinks.";
    };

    zshPlugins = {
      autosuggestions.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable zsh-autosuggestions, suggesting commands as you type based on history. Sourced via zsh-defer so it doesn't block shell startup.";
      };
      syntaxHighlighting.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable zsh-syntax-highlighting, highlighting commands as they are typed. Sourced via zsh-defer so it doesn't block shell startup.";
      };
      completions.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable zsh-completions, a collection of additional completion definitions.";
      };
      commaAssistant.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable zsh-comma-assistant: friendlier command-not-found handling (offers to run unknown commands via comma) and, when zshPlugins.syntaxHighlighting is also enabled, highlights commands available via comma/nix-index. Requires ft.nixIndex.enable for the comma binary and database; no-ops if that's disabled. Sourced via zsh-defer so it doesn't block shell startup.";
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

        # Skip compinit's security audit unless the dump is more than a day
        # old, so completion setup doesn't rescan fpath on every shell start.
        completionInit = lib.mkDefault ''
          autoload -Uz compinit
          for dump in ''${ZDOTDIR:-$HOME}/.zcompdump(N.mh+24); do
            compinit
          done
          compinit -C
        '';

        history = {
          size = lib.mkDefault 10000;
          save = lib.mkDefault 10000;
          ignoreDups = lib.mkDefault true;
          extended = lib.mkDefault true;
        };

        plugins = lib.optional cfg.zshPlugins.completions.enable {
          name = "zsh-completions";
          src = pkgs.zsh-completions;
        };

        # autosuggestions/syntax-highlighting/comma-assistant are sourced
        # through zsh-defer (below) rather than the native
        # autosuggestion/syntaxHighlighting options, since those source
        # eagerly and block shell startup. zsh-defer preserves enqueue
        # order, so comma-assistant's highlighter addon (queued last)
        # always loads after zsh-syntax-highlighting itself.
        initContent = lib.mkMerge [
          (lib.mkDefault "source ${config.ft.dotfiles.path}/zsh/.zshrc")
          (lib.mkAfter (
            let
              commaAssistantEnable = cfg.zshPlugins.commaAssistant.enable && config.ft.nixIndex.enable;
            in
            lib.optionalString
              (cfg.zshPlugins.autosuggestions.enable || cfg.zshPlugins.syntaxHighlighting.enable || commaAssistantEnable)
              "source ${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh\n"
            + lib.optionalString cfg.zshPlugins.autosuggestions.enable
              "zsh-defer source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh\n"
            + lib.optionalString cfg.zshPlugins.syntaxHighlighting.enable
              "zsh-defer source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh\n"
            + lib.optionalString commaAssistantEnable
              "zsh-defer source ${commaAssistantSrc}/zsh-comma-assistant.plugin.zsh\n"
          ))
        ];
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
