_:

{
  # ----------------------------------------------------------------------------
  # IDENTITY
  # ----------------------------------------------------------------------------
  home.username = "admin";
  ft.core.stateVersion = "25.05";

  programs.git = {
    enable = true;
    settings.user = {
      name = "admin";
      email = "admin@fasttrack.os";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  # ----------------------------------------------------------------------------
  # FEATURE FLAGS
  # ----------------------------------------------------------------------------
  # ft.* options are available because the generator injects modules/home.
  # Do not import framework modules here — the generator already does it.
}
