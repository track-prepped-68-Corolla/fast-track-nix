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
  # TODO: hash is a placeholder (lib.fakeHash) pending a real one computed
  # with `nix`; zshPlugins.commaAssistant.enable defaults to false until
  # it's replaced, since fast-track-nix's own CI only evaluates and won't
  # catch a wrong hash — it would otherwise break consumer builds silently.
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
      description = "Sets up a complete terminal environment: the `ghostty` terminal emulator, zsh configured from your dotfiles with plugins that load lazily, the starship prompt, `zoxide`, `fzf`, and a curated set of everyday CLI tools like `bat`, `eza`, `btop`, `fd`, `ripgrep`, `yazi`, `lazygit`, and `tealdeer`. The starship and ghostty config files are linked directly from your dotfiles, so edits take effect immediately.";
    };

    zshPlugins = {
      autosuggestions.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Suggests commands as you type, based on your shell history. Loaded lazily via zsh-defer so it doesn't slow down shell startup.";
      };
      syntaxHighlighting.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Highlights commands in your shell as you type them. Loaded lazily via zsh-defer so it doesn't slow down shell startup.";
      };
      completions.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Adds a larger collection of tab-completion definitions for zsh.";
      };
      commaAssistant.enable = lib.mkOption {
        type = lib.types.bool;
        # Defaults off: commaAssistantSrc's fetchFromGitHub hash below is
        # still a lib.fakeHash placeholder (no local nix available to
        # compute the real one) — enabling this will fail the build until
        # it's replaced with the actual NAR hash.
        default = false;
        description = "Makes 'command not found' errors friendlier by offering to run the missing command via `comma`, and — when `zshPlugins.syntaxHighlighting` is also on — highlights commands that are available through comma/nix-index. Needs `ft.nixIndex.enable` for the `comma` binary and its database; does nothing if that's off. Loaded lazily via zsh-defer so it doesn't slow down shell startup. Note: this currently defaults to off because the pinned source still uses a placeholder hash instead of a real one.";
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
            lib.optionalString (
              cfg.zshPlugins.autosuggestions.enable
              || cfg.zshPlugins.syntaxHighlighting.enable
              || commaAssistantEnable
            ) "source ${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh\n"
            + lib.optionalString cfg.zshPlugins.autosuggestions.enable "zsh-defer source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh\n"
            + lib.optionalString cfg.zshPlugins.syntaxHighlighting.enable "zsh-defer source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh\n"
            + lib.optionalString commaAssistantEnable "zsh-defer source ${commaAssistantSrc}/zsh-comma-assistant.plugin.zsh\n"
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
