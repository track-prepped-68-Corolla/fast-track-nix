_:

{
  # ----------------------------------------------------------------------------
  # IDENTITY
  # ----------------------------------------------------------------------------
  home.username = "admin";
  ft.home.core.stateVersion = "25.05";

  programs.git = {
    enable = true;
    userName = "admin";
    userEmail = "admin@fasttrack.os";
    delta.enable = true;
  };

  # ----------------------------------------------------------------------------
  # FEATURE FLAGS
  # ----------------------------------------------------------------------------
  # ft.* options are available because the generator injects modules/home.
  # Do not import framework modules here — the generator already does it.
}
