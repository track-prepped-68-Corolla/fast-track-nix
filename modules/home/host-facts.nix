{ config, lib, inputs, ... }:

let
  h          = config.ft.primaryHost;
  factsFile  = inputs.self + "/hosts/${h}/var/facter.json";
  facter     = if h != "" && builtins.pathExists factsFile
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
  options.ft.hostFacts = lib.mkOption {
    type        = lib.types.attrsOf lib.types.anything;
    default     = {};
    readOnly    = true;
    description = "Hardware facts from hosts/<primaryHost>/var/facter.json. Includes raw facter data plus derived .gpu attrset.";
  };

  config.ft.hostFacts = facter // {
    gpu = {
      vendor    = gpuVendor;
      hasNvidia = lib.hasInfix "nvidia" gpuVendor;
      hasAmd    = lib.hasInfix "amd" gpuVendor;
    };
  };
}
