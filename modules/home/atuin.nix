{
  config,
  lib,
  ...
}:

################################################################################
# ATUIN MODULE (Home Manager)
# ------------------------------------------------------------------------------
# SQLite-backed, searchable shell history with a fuzzy TUI. Local-only: no
# sync account, no sync daemon. Takes over Ctrl+R and the up-arrow key.
################################################################################

let
  cfg = config.ft.atuin;
in
{
  options.ft.atuin = {
    enable = lib.mkEnableOption "atuin shell history" // {
      description = "Replaces zsh's plain history search with atuin: a SQLite-backed, searchable shell history with a fuzzy TUI. Local-only by default — no sync account or daemon. Takes over Ctrl+R and the up-arrow key; if ft.terminal's fzf integration is also enabled, fzf's Ctrl+T/Alt+C bindings are unaffected since atuin's shell init runs after fzf's and only rebinds Ctrl+R and up-arrow.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.atuin = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
    };
  };
}
