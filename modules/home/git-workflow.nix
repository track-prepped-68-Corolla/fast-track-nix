{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.ft.gitWorkflow;

  conformConfig = pkgs.writeText "conform.yaml" (
    "policies:\n"
    + "  - type: commit\n"
    + "    spec:\n"
    + "      conventional:\n"
    + "        types:\n"
    + lib.concatMapStrings (t: "          - ${t}\n") cfg.types
    + "        scopes: []\n"
    + "        descriptionLength: 72\n"
  );

  secretsCheck = pkgs.writeShellScript "ft-secrets-check" ''
    if command -v trufflehog &>/dev/null; then
      trufflehog git file://. --since-commit HEAD --fail 2>/dev/null
    else
      echo ":: trufflehog not in PATH — secret scan skipped ::"
    fi
  '';

  # The nixpkgs-pinned conform release has no --config flag on `enforce`; it
  # only ever reads ./.conform.yaml relative to cwd. Symlink our generated
  # config into place at the repo root (excluded from git locally, never
  # tracked) so `conform enforce` finds it regardless of which directory the
  # hook is invoked from.
  conformCheck = pkgs.writeShellScript "ft-conform-check" ''
    set -e
    toplevel="$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
    ln -sf ${conformConfig} "$toplevel/.conform.yaml"
    excludeFile="$toplevel/.git/info/exclude"
    if ! grep -qxF ".conform.yaml" "$excludeFile" 2>/dev/null; then
      echo ".conform.yaml" >> "$excludeFile"
    fi
    cd "$toplevel"
    exec ${pkgs.conform}/bin/conform enforce --commit-msg-file "$1"
  '';

  lefthookConfig = pkgs.writeText "lefthook.yml" (
    "pre-commit:\n"
    + "  commands:\n"
    + "    format-check:\n"
    + "      run: \"${pkgs.treefmt}/bin/treefmt --fail-on-change\"\n"
    + "    secrets:\n"
    + "      run: \"${secretsCheck}\"\n"
    + "\n"
    + "commit-msg:\n"
    + "  commands:\n"
    + "    conform:\n"
    + "      run: \"${conformCheck} {1}\"\n"
  );
in
{
  options.ft.gitWorkflow = {
    enable = lib.mkEnableOption "lefthook conventional commit workflow" // {
      description = "Sets up a conventional-commit workflow for git: installs `conform`, `convco`, and `lefthook`, then wires up global git hooks (via `core.hooksPath`) that check formatting with treefmt and scan for secrets with trufflehog before each commit, and enforce conventional commit message format when you write the message. It also appends NixOS generation info (written by the `ft` switch recipe) to your commit messages automatically, and gives you `convco`'s interactive commit builder.";
    };

    types = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "feat"
        "fix"
        "chore"
        "refactor"
        "docs"
        "style"
        "test"
        "ci"
        "perf"
        "build"
        "revert"
      ];
      description = "The commit types allowed in conventional commit messages. The commit-msg hook rejects any commit whose type isn't on this list.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      conform
      convco
      lefthook
    ];

    programs.git.enable = lib.mkDefault true;

    programs.git.extraConfig = lib.mkDefault {
      core.hooksPath = "${config.home.homeDirectory}/.config/git/hooks";
    };

    home.file = {
      ".config/git/hooks/pre-commit" = lib.mkDefault {
        source = pkgs.writeShellScript "ft-pre-commit" ''
          LEFTHOOK_CONFIG=${lefthookConfig} exec ${pkgs.lefthook}/bin/lefthook run pre-commit
        '';
      };
      ".config/git/hooks/commit-msg" = lib.mkDefault {
        source = pkgs.writeShellScript "ft-commit-msg" ''
          LEFTHOOK_CONFIG=${lefthookConfig} exec ${pkgs.lefthook}/bin/lefthook run commit-msg "$@"
        '';
      };
      ".config/git/hooks/prepare-commit-msg" = lib.mkDefault {
        source = pkgs.writeShellScript "ft-prepare-commit-msg" ''
          switch_info="$(git rev-parse --git-dir 2>/dev/null)/FT_SWITCH_INFO"
          if [ -f "$switch_info" ]; then
            printf '\n%s' "$(cat "$switch_info")" >> "$1"
            rm -f "$switch_info"
          fi
        '';
      };
    };
  };
}
