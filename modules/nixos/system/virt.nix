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
      description = "Sets up virtual machine support with libvirt/KVM and virt-manager, and adds `ft.users.mainUser` to the libvirtd group so they can manage VMs. You can also turn on `ft.virt.enableVmwareHost` for VMware Workstation, `ft.virt.enableIncus` for Incus containers, and `ft.virt.enableSpiceUsbRedirection` to pass USB devices through to VMs.";
    };

    enableVmwareHost = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Turn on support for running VMware Workstation on this machine.";
    };

    enableIncus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Turn on Incus, the LXD-based container and VM hypervisor.";
    };

    enableSpiceUsbRedirection = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Turn on SPICE USB redirection, letting VMs use USB devices plugged into the host.";
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
