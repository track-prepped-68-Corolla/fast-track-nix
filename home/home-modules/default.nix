{ config, pkgs, ... }:

################################################################################
# HOME MODULES HUB (The Central Registry)
# ------------------------------------------------------------------------------
# This file is the "Brain" of your user environment.
#
# ROLE:
# It gathers every piece of logic (Core, Interface, Tools) into one place.
#
# ------------------------------------------------------------------------------
# 📚 CRASH COURSE: RELATIVE PATHS IN NIX
# ------------------------------------------------------------------------------
# In Nix imports, we use "Relative Paths" to point to other files.
# Imagine a file system map where you are "standing" inside this file.
#
# "./"   (DOT-SLASH)
# Means: "Look in the SAME FOLDER I am currently in."
# Example: ./terminal.nix means "the terminal.nix file right next to me."
#
# "../"  (DOT-DOT-SLASH)
# Means: "Go UP one folder level (to the parent)."
# Example: ../flake.nix means "Exit this folder, then look for flake.nix."
#
# "../../" (DOT-DOT-SLASH-DOT-DOT-SLASH)
# Means: "Go UP two folder levels."
# Example: Used in your user file to reach this module folder from deep inside
#          the user directory.
################################################################################

{
  imports = [
    # --------------------------------------------------------------------------
    # 1. THE CORE FOUNDATION
    # --------------------------------------------------------------------------
    # Path: ./home-core.nix
    # Translation: "Import the home-core.nix file sitting right next to me."
    #
    # WHAT IT DOES:
    # - Sets mandatory settings (stateVersion).
    # - Auto-detects home directory.
    # - Enables Home Manager self-management.
    ./home-core.nix

    ./stylix.nix

    # --------------------------------------------------------------------------
    # 2. THE INTERFACE (Terminal & Shell)
    # --------------------------------------------------------------------------
    # Path: ./terminal.nix
    # Translation: "Import the terminal.nix file sitting right next to me."
    #
    # WHAT IT DOES:
    # - Installs 'kitty' (Terminal) & 'zsh' (Shell).
    # - Configures Neovim as a "Trojan Horse" (Notepad-style bindings).
    # - Installs core CLI tools (git, bat, eza).
    ./terminal.nix

    # --------------------------------------------------------------------------
    # 3. THE WORKSTATION TOOLS (Containers)
    # --------------------------------------------------------------------------
    # Path: ./podman-user.nix
    # Translation: "Import the podman-user.nix file sitting right next to me."
    #
    # WHAT IT DOES:
    # - Installs 'lazydocker' dashboard.
    # - Configures container aliases (docker -> podman).
    # - This is OPT-IN via 'ft.containers.enable = true'.
    #./podman-user.nix

    # --------------------------------------------------------------------------
    # 4. GAMING (Coming Soon...)
    # --------------------------------------------------------------------------
    # Path: ./gaming.nix
    #
    # WHAT IT WILL DO:
    # - Install Steam, Proton, and performance tweaks.
    # - ./gaming.nix

    # --------------------------------------------------------------------------
    # 5. IDE & EDITOR (LazyVim)
    # --------------------------------------------------------------------------
    # Path: ./lazyvim.nix
    #
    # WHAT IT WILL DO:
    # - Install Neovim and core system dependencies (ripgrep, fd, gcc).
    # - Provision LSPs and formatters for Python, Go, Rust, C/C++, Web, XML, and Nix.
    # - Create a mutable, out-of-store symlink to your LazyVim Lua dotfiles.
    # - Configured to toggle on/off via `ft.lazyvim.enable`.
    ./lazyvim.nix

  ];
}
