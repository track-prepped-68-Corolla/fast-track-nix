# Todo List

## Pending Review
- [x] Consolidate `nixos-config/modules/containers/ai.nix` and `nixos-config/modules/containers/aiz.nix` into a single, more flexible `ai.nix` module in `ft-home`. This module should allow for easy configuration of different AI models and frontends.
- [x] Migrate `nixos-config/modules/containers/arr.nix` (Sonarr, Radarr, Lidarr, etc.) to `ft-home`, ensuring proper configuration for media management.
- [x] Consolidate `nixos-config/modules/containers/comfyrocm.nix` and `nixos-config/modules/containers/comfyui.nix` into a single, robust `comfyui.nix` module in `ft-home`. This module should support both ROCm and potentially CUDA/other backends with clear configuration options.
- [x] Migrate `nixos-config/modules/containers/distrobox.nix` for managing development environments.
- [x] Migrate `nixos-config/modules/containers/dozzle.nix` for real-time container logs.
- [x] Migrate `nixos-config/modules/containers/jellyfin.nix` for media streaming.
- [x] Migrate `nixos-config/modules/containers/searxng.nix` for a private metasearch engine.
- [x] Compare and potentially migrate `nixos-config/modules/desktops/plasma.nix` and `nixos-config/modules/desktops/cosmic.nix` to `ft-home`. The goal is to create flexible desktop modules that can be easily enabled/disabled.
- [x] Compare `nixos-config/modules/hardware/nvidia.nix` and `ft-home/nixos/modules/hardware/nvidia.nix`. Ensure `ft-home`'s module is up-to-date and incorporates best practices for NVIDIA setup and implement prime, amd, and intel functionality to turn it into a universal gpu module.
- [x] Create `nixos/modules/hardware/yubikey.nix` for YubiKey integration (e.g., PAM, SSH).
- [x] Compare `nixos-config/modules/profiles/couchgaming.nix` along with `nixos-config/modules/profiles/gaming.nix` and `ft-home/nixos/modules/profiles/couch-gaming.nix`. rename to gaming.nix, include boolean toggles for pc or leanback ui, and Consolidate and improve the existing module.
- [x] Compare `nixos-config/modules/services/nfs.nix` and `ft-home/nixos/modules/hardware/nfs.nix`. Reconcile and ensure a robust NFS server/client setup.
- [x] Create `nixos/modules/services/printing.nix` for CUPS and printer management.
- [x] Create `nixos/modules/services/tailscale.nix` for Tailscale VPN integration.
- [x] Create `nixos/modules/system/virt.nix` for virtualization (e.g., QEMU/KVM) setup.
- [x] Compare `nixos-config/modules/system/podman.nix` and `ft-home/nixos/modules/system/podman-system.nix`. Consolidate and enhance the Podman system module, potentially including NVIDIA container toolkit integration as an option.
- [x] Compare `modules/system/nh.nix` to `nixos/modules/system/maintnenace.nix` for `nh` CLI tool configuration and prompt the user about desired functionality.
- [ ] Evaluate apps installed across all nix files in nixos-config and add items to the todo list to add these functions to ft-home.


## Areas for Improvement
- [ ] Consolidate similar modules (e.g., `nvidia.nix` and `amd.nix` if they share common structures) by creating a more generic `gpu.nix` module with conditional logic.
- [ ] Standardize module structure and commenting for better readability and maintainability across the entire `ft-home` repository.
- [ ] Review all modules for security best practices and adherence to NixOS conventions, ensuring a robust and secure configuration.
- [ ] Implement robust error handling and fallback mechanisms in new modules.
- [ ] Add comprehensive documentation for each new module, explaining its purpose, options, and usage examples.