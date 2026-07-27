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
      description = "Replaces zsh's plain history search with atuin, which stores your shell history in a searchable database and gives you a fuzzy-search popup for it. It works entirely offline, with no sync account or background service. It takes over Ctrl+R and the up-arrow key; if `ft.terminal`'s fzf integration is also on, fzf's own Ctrl+T/Alt+C shortcuts are unaffected because atuin loads after fzf and only touches those two bindings.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.atuin = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
    };
  };
}
