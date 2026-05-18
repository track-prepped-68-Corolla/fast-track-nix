{ config, lib, inputs, ... }:

let
  hf          = inputs.self + "/var/local/machineName";
  machineName = if builtins.pathExists hf
                then lib.removeSuffix "\n" (builtins.readFile hf)
                else "";
  factsFile   = inputs.self + "/machines/${machineName}/var/facter.json";
  facter      = if machineName != "" && builtins.pathExists factsFile
                then builtins.fromJSON (builtins.readFile factsFile)
                else {};
  pciDevices = facter.hardware.pci_devices or [];
  gpuDevices = builtins.filter
    (d: (d.class_id or "") == "0300" || (d.class_id or "") == "0302")
    pciDevices;
  gpuVendor  = lib.toLower (
    if gpuDevices != []
    then (builtins.head gpuDevices).vendor_name or "unknown"
    else "unknown"
  );
in
{
  options.ft.machineFacts = lib.mkOption {
    type        = lib.types.attrsOf lib.types.anything;
    default     = {};
    readOnly    = true;
    description = "Hardware facts from machines/<machineName>/var/facter.json. machineName is read from var/local/machineName.";
  };

  config.ft.machineFacts = facter // {
    gpu = {
      vendor    = gpuVendor;
      hasNvidia = lib.hasInfix "nvidia" gpuVendor;
      hasAmd    = lib.hasInfix "amd" gpuVendor;
    };
  };
}
