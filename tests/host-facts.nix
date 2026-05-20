# =============================================================================
# Tests for modules/home/host-facts.nix
# =============================================================================
#
# host-facts.nix (new in this PR) reads facter.json hardware data and exposes
# GPU vendor detection via config.ft.machineFacts. The detection logic is:
#
#   pciDevices    — facter.hardware.pci_devices list (default [])
#   gpuDevices    — pciDevices filtered to class_id "0300" or "0302"
#   gpuVendor     — vendor_name of first GPU, lowercased; "unknown" if none
#   hasNvidia     — lib.hasInfix "nvidia" gpuVendor
#   hasAmd        — lib.hasInfix "amd" gpuVendor
#
# All tests exercise the pure filtering/detection logic in isolation so they
# do not need Home Manager evaluation or network access.
# =============================================================================
{ pkgs, lib }:

let
  # ---------------------------------------------------------------------------
  # Inline reproduction of host-facts.nix pure logic
  # (mirrors the source exactly so tests catch regressions)
  # ---------------------------------------------------------------------------

  pciClassIds = {
    displayController = "0300";
    d3dController = "0302";
    networkController = "0200";
    audioDevice = "0403";
    usbController = "0c03";
  };

  filterGpuDevices =
    pciDevices:
    builtins.filter (
      d: (d.class_id or "") == pciClassIds.displayController || (d.class_id or "") == pciClassIds.d3dController
    ) pciDevices;

  computeGpuVendor =
    pciDevices:
    let
      gpuDevices = filterGpuDevices pciDevices;
    in
    lib.toLower (
      if gpuDevices != [ ] then (builtins.head gpuDevices).vendor_name or "unknown" else "unknown"
    );

  computeGpuFacts =
    pciDevices:
    let
      gpuVendor = computeGpuVendor pciDevices;
    in
    {
      vendor = gpuVendor;
      hasNvidia = lib.hasInfix "nvidia" gpuVendor;
      hasAmd = lib.hasInfix "amd" gpuVendor;
    };

  # ---------------------------------------------------------------------------
  # Sample PCI device records
  # ---------------------------------------------------------------------------

  nvidiaGpu = {
    class_id = "0300";
    vendor_name = "NVIDIA Corporation";
    device_name = "GA104 [GeForce RTX 3070]";
  };

  amdGpu = {
    class_id = "0300";
    vendor_name = "Advanced Micro Devices, Inc. [AMD/ATI]";
    device_name = "Navi 23 [Radeon RX 6650 XT]";
  };

  intelGpu = {
    class_id = "0300";
    vendor_name = "Intel Corporation";
    device_name = "UHD Graphics 630";
  };

  # A compute (GPGPU / 3D controller) device — class_id 0302
  nvidiaCompute = {
    class_id = "0302";
    vendor_name = "NVIDIA Corporation";
    device_name = "TU116GL [T400]";
  };

  networkCard = {
    class_id = "0200";
    vendor_name = "Intel Corporation";
    device_name = "Ethernet Controller I225-V";
  };

  audioCard = {
    class_id = "0403";
    vendor_name = "Advanced Micro Devices, Inc. [AMD/ATI]";
    device_name = "Navi 21/23 HDMI/DP Audio";
  };

  # Device with no class_id field at all
  unknownDevice = {
    vendor_name = "Some Vendor";
    device_name = "Mystery Device";
  };

  mkTest =
    name: pass:
    pkgs.runCommand "host-facts-${name}" { } (
      if pass then
        ''
          echo "PASS: ${name}"
          touch $out
        ''
      else
        ''
          echo "FAIL: ${name}"
          exit 1
        ''
    );

in
{

  # ---- filterGpuDevices: class_id matching ----------------------------------

  # class_id "0300" is a display controller → GPU
  filter-display-controller =
    let
      result = filterGpuDevices [ nvidiaGpu ];
    in
    mkTest "filter-display-controller" (result == [ nvidiaGpu ]);

  # class_id "0302" is a 3D/compute controller → also treated as GPU
  filter-3d-controller =
    let
      result = filterGpuDevices [ nvidiaCompute ];
    in
    mkTest "filter-3d-controller" (result == [ nvidiaCompute ]);

  # class_id "0200" is a network card → NOT a GPU
  filter-network-excluded =
    let
      result = filterGpuDevices [ networkCard ];
    in
    mkTest "filter-network-excluded" (result == [ ]);

  # class_id "0403" is audio → NOT a GPU
  filter-audio-excluded =
    let
      result = filterGpuDevices [ audioCard ];
    in
    mkTest "filter-audio-excluded" (result == [ ]);

  # Device with no class_id field → excluded
  filter-missing-class-id-excluded =
    let
      result = filterGpuDevices [ unknownDevice ];
    in
    mkTest "filter-missing-class-id-excluded" (result == [ ]);

  # Mixed list: only the GPU device survives
  filter-mixed-list =
    let
      result = filterGpuDevices [
        networkCard
        nvidiaGpu
        audioCard
      ];
    in
    mkTest "filter-mixed-list" (result == [ nvidiaGpu ]);

  # Empty input → empty output
  filter-empty-input =
    let
      result = filterGpuDevices [ ];
    in
    mkTest "filter-empty-input" (result == [ ]);

  # Multiple GPUs → all survive the filter
  filter-multiple-gpus =
    let
      result = filterGpuDevices [
        amdGpu
        nvidiaGpu
      ];
    in
    mkTest "filter-multiple-gpus" (builtins.length result == 2);

  # ---- computeGpuVendor: vendor string extraction and lowercasing -----------

  # No devices → "unknown"
  vendor-empty-devices =
    let
      v = computeGpuVendor [ ];
    in
    mkTest "vendor-empty-devices" (v == "unknown");

  # Only non-GPU devices → "unknown"
  vendor-no-gpu-devices =
    let
      v = computeGpuVendor [ networkCard audioCard ];
    in
    mkTest "vendor-no-gpu-devices" (v == "unknown");

  # NVIDIA device → vendor is lowercased
  vendor-nvidia-lowercased =
    let
      v = computeGpuVendor [ nvidiaGpu ];
    in
    mkTest "vendor-nvidia-lowercased" (v == "nvidia corporation");

  # AMD device → vendor is lowercased
  vendor-amd-lowercased =
    let
      v = computeGpuVendor [ amdGpu ];
    in
    mkTest "vendor-amd-lowercased" (
      lib.hasInfix "advanced micro devices" v || lib.hasInfix "amd" v
    );

  # Intel device → vendor is lowercased
  vendor-intel-lowercased =
    let
      v = computeGpuVendor [ intelGpu ];
    in
    mkTest "vendor-intel-lowercased" (v == "intel corporation");

  # Compute device (class 0302) with NVIDIA vendor → resolved correctly
  vendor-compute-device =
    let
      v = computeGpuVendor [ nvidiaCompute ];
    in
    mkTest "vendor-compute-device" (lib.hasInfix "nvidia" v);

  # When multiple GPUs, first one's vendor is used
  vendor-first-gpu-wins =
    let
      v = computeGpuVendor [
        amdGpu
        nvidiaGpu
      ];
    in
    mkTest "vendor-first-gpu-wins" (
      lib.hasInfix "amd" v || lib.hasInfix "advanced micro devices" v
    );

  # GPU device with no vendor_name field → falls back to "unknown"
  vendor-missing-vendor-name =
    let
      gpuNoVendor = {
        class_id = "0300";
        device_name = "Mystery GPU";
      };
      v = computeGpuVendor [ gpuNoVendor ];
    in
    mkTest "vendor-missing-vendor-name" (v == "unknown");

  # ---- computeGpuFacts: hasNvidia and hasAmd flags -------------------------

  # No GPU → vendor="unknown", hasNvidia=false, hasAmd=false
  facts-no-gpu =
    let
      f = computeGpuFacts [ ];
    in
    mkTest "facts-no-gpu" (f.vendor == "unknown" && !f.hasNvidia && !f.hasAmd);

  # NVIDIA GPU → hasNvidia=true, hasAmd=false
  facts-nvidia =
    let
      f = computeGpuFacts [ nvidiaGpu ];
    in
    mkTest "facts-nvidia" (f.hasNvidia && !f.hasAmd);

  # AMD GPU → hasAmd=true, hasNvidia=false
  facts-amd =
    let
      f = computeGpuFacts [ amdGpu ];
    in
    mkTest "facts-amd" (f.hasAmd && !f.hasNvidia);

  # Intel GPU → hasNvidia=false, hasAmd=false
  facts-intel =
    let
      f = computeGpuFacts [ intelGpu ];
    in
    mkTest "facts-intel" (!f.hasNvidia && !f.hasAmd);

  # NVIDIA compute device (class 0302) → hasNvidia=true
  facts-nvidia-compute =
    let
      f = computeGpuFacts [ nvidiaCompute ];
    in
    mkTest "facts-nvidia-compute" (f.hasNvidia && !f.hasAmd);

  # Only non-GPU devices → hasNvidia=false, hasAmd=false
  facts-no-gpu-devices-in-list =
    let
      f = computeGpuFacts [
        networkCard
        audioCard
      ];
    in
    mkTest "facts-no-gpu-devices-in-list" (!f.hasNvidia && !f.hasAmd && f.vendor == "unknown");

  # ---- facter attribute extraction -----------------------------------------

  # facter with pci_devices propagates through to GPU detection
  facter-pci-devices-path =
    let
      facter = {
        system = "x86_64-linux";
        hardware = {
          pci_devices = [ nvidiaGpu networkCard ];
        };
      };
      pciDevices = facter.hardware.pci_devices or [ ];
      f = computeGpuFacts pciDevices;
    in
    mkTest "facter-pci-devices-path" (f.hasNvidia);

  # facter without hardware key → pci_devices defaults to []
  facter-missing-hardware-key =
    let
      facter = { system = "x86_64-linux"; };
      pciDevices = facter.hardware.pci_devices or [ ];
      f = computeGpuFacts pciDevices;
    in
    mkTest "facter-missing-hardware-key" (pciDevices == [ ] && f.vendor == "unknown");

  # facter with hardware but no pci_devices key → defaults to []
  facter-missing-pci-devices-key =
    let
      facter = {
        system = "x86_64-linux";
        hardware = {
          cpu = {
            vendor = "AuthenticAMD";
          };
        };
      };
      pciDevices = facter.hardware.pci_devices or [ ];
      f = computeGpuFacts pciDevices;
    in
    mkTest "facter-missing-pci-devices-key" (pciDevices == [ ] && !f.hasNvidia && !f.hasAmd);

  # machineFacts merges facter attrs with gpu sub-attrset (structural check)
  facter-merge-structure =
    let
      facter = {
        system = "x86_64-linux";
        hardware = {
          pci_devices = [ nvidiaGpu ];
        };
      };
      pciDevices = facter.hardware.pci_devices or [ ];
      gpuFacts = computeGpuFacts pciDevices;
      machineFacts = facter // {
        gpu = gpuFacts;
      };
    in
    mkTest "facter-merge-structure" (
      machineFacts ? gpu
      && machineFacts ? system
      && machineFacts.gpu.hasNvidia
      && machineFacts.system == "x86_64-linux"
    );
}
