{
  config,
  lib,
  pkgs,
  ...
}:

################################################################################
# VIRTUALIZATION MODULE
################################################################################

let
  cfg = config.ft.system.virt;
in
{
  options.ft.system.virt = {
    enable = lib.mkEnableOption "Comprehensive virtualization setup (Libvirt, Incus, VMware)" // {
      description = "Enables libvirtd/KVM with virt-manager and adds `mainuser` to the libvirtd group. Optionally enable `ft.system.virt.enableVmwareHost` for VMware Workstation, `ft.system.virt.enableIncus` for Incus containers, and `ft.system.virt.enableSpiceUsbRedirection` for USB passthrough to VMs.";
    };

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
    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = cfg.enableSpiceUsbRedirection;
      vmware.host.enable = lib.mkIf cfg.enableVmwareHost true;
      incus = lib.mkIf cfg.enableIncus {
        enable = true;
        package = pkgs.incus;
      };
    };
    programs.virt-manager.enable = true;
    users.groups.libvirtd.members = [ config.mainuser ];
    networking.nftables.enable = lib.mkDefault true;
  };
}
