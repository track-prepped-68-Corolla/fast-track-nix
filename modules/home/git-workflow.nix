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
    + "      run: \"${pkgs.conform}/bin/conform enforce --commit-msg-file {1} --config ${conformConfig}\"\n"
  );
in
{
  options.ft.gitWorkflow = {
    enable = lib.mkEnableOption "lefthook conventional commit workflow" // {
      description = "Installs conform, convco, and lefthook; registers global git hooks via core.hooksPath that run treefmt format-checking and trufflehog secret scanning on pre-commit, and enforce conventional commit format on commit-msg. The prepare-commit-msg hook appends NixOS generation metadata written by the ft switch recipe. Enables the convco interactive commit builder.";
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
      description = "Allowed conventional commit types. The commit-msg hook rejects messages whose type is not in this list.";
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
