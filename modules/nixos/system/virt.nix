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
  cfg = config.ft.virt;
in
{
  options.ft.virt = {
    enable = lib.mkEnableOption "Comprehensive virtualization setup (Libvirt, Incus, VMware)" // {
      description = "Enables libvirtd/KVM with virt-manager and adds `ft.users.mainUser` to the libvirtd group. Optionally enable `ft.virt.enableVmwareHost` for VMware Workstation, `ft.virt.enableIncus` for Incus containers, and `ft.virt.enableSpiceUsbRedirection` for USB passthrough to VMs.";
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
    users.groups.libvirtd.members = [ config.ft.users.mainUser ];
    networking.nftables.enable = lib.mkDefault true;
  };
}
