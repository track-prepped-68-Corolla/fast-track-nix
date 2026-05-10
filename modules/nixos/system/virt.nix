{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# VIRTUALIZATION MODULE
# ------------------------------------------------------------------------------
# This module provides a comprehensive setup for various virtualization
# technologies, including Libvirt (KVM/QEMU), Incus (LXD fork), and VMware
# workstation. It aims to offer a unified configuration for managing virtual
# machines and containers on NixOS.
################################################################################

let
  cfg = config.ft.system.virt;
in
{
  options.ft.system.virt = {
    enable = lib.mkEnableOption "Comprehensive virtualization setup (Libvirt, Incus, VMware)";

    enableVmwareHost = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable VMware Workstation host support.";
    };

    enableIncus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Incus (LXD fork) container hypervisor.";
    };

    enableSpiceUsbRedirection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPICE USB redirection for VMs.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
    users.groups.libvirtd.members = [ config.mainuser ];
    virtualisation.spiceUSBRedirection.enable = cfg.enableSpiceUsbRedirection;
    virtualisation.vmware.host.enable = lib.mkIf cfg.enableVmwareHost true;
    virtualisation.incus = lib.mkIf cfg.enableIncus {
      enable = true;
      package = pkgs.incus;
    };
    networking.nftables.enable = lib.mkDefault true;
  };
}
