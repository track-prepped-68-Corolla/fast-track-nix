# Replace "myuser" with your actual username throughout this repo.
_: {
  home.username = "myuser";
  ft.core.stateVersion = "25.05"; # set once at install time, never change

  programs.git = {
    enable = true;
    userName = "My Name";
    userEmail = "me@example.com";
  };
}
