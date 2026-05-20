# =============================================================================
# Tests for modules/home/host-facts.nix
# =============================================================================
#
# Covers the pure logic embedded in the module's let block:
#   - pciDevices extraction from facter (with fallback to [])
#   - gpuDevices filter: keeps only class_id "0300" or "0302"
#   - gpuVendor: toLower of first GPU's vendor_name, or "unknown" when absent
#   - hasNvidia: true when gpuVendor contains "nvidia" (case-insensitive via toLower)
#   - hasAmd: true when gpuVendor contains "amd"
#   - Interaction between multiple GPU entries (first wins)
#   - Non-GPU PCI devices are excluded
# =============================================================================
{ lib, pkgs }:

let
  # ---------------------------------------------------------------------------
  # Re-implement the pure GPU-detection helpers from host-facts.nix so they can
  # be exercised without a Home Manager evaluation context.
  # ---------------------------------------------------------------------------

  # Extract PCI device list from a facter attrset (mirrors host-facts.nix line 16).
  getPciDevices = facter: facter.hardware.pci_devices or [ ];

  # Filter PCI devices to display-class entries (mirrors host-facts.nix lines 17-19).
  getGpuDevices =
    pciDevices:
    builtins.filter (d: (d.class_id or "") == "0300" || (d.class_id or "") == "0302") pciDevices;

  # Derive GPU vendor string from the device list (mirrors host-facts.nix lines 20-22).
  getGpuVendor =
    gpuDevices:
    lib.toLower (
      if gpuDevices != [ ] then (builtins.head gpuDevices).vendor_name or "unknown" else "unknown"
    );

  # Compose: facter → { vendor, hasNvidia, hasAmd } (mirrors host-facts.nix lines 33-37).
  gpuFacts =
    facter:
    let
      pciDevices = getPciDevices facter;
      gpuDevices = getGpuDevices pciDevices;
      gpuVendor = getGpuVendor gpuDevices;
    in
    {
      vendor = gpuVendor;
      hasNvidia = lib.hasInfix "nvidia" gpuVendor;
      hasAmd = lib.hasInfix "amd" gpuVendor;
    };

  # ---------------------------------------------------------------------------
  # Fixture facter attrsets
  # ---------------------------------------------------------------------------

  emptyFacter = { };

  nvidiaFacter = {
    hardware.pci_devices = [
      {
        class_id = "0300";
        vendor_name = "NVIDIA Corporation";
        device_name = "GA102 [GeForce RTX 3080]";
      }
    ];
  };

  amdFacter = {
    hardware.pci_devices = [
      {
        class_id = "0300";
        vendor_name = "Advanced Micro Devices, Inc. [AMD/ATI]";
        device_name = "Navi 22 [Radeon RX 6700 XT]";
      }
    ];
  };

  intelFacter = {
    hardware.pci_devices = [
      {
        class_id = "0300";
        vendor_name = "Intel Corporation";
        device_name = "UHD Graphics 770";
      }
    ];
  };

  # A secondary compute GPU using class_id 0302 (3D controller).
  computeGpuFacter = {
    hardware.pci_devices = [
      {
        class_id = "0302";
        vendor_name = "NVIDIA Corporation";
        device_name = "GV100GL [Tesla V100]";
      }
    ];
  };

  # Non-GPU device only (class_id 0200 = Network controller).
  nonGpuFacter = {
    hardware.pci_devices = [
      {
        class_id = "0200";
        vendor_name = "Intel Corporation";
        device_name = "Ethernet Controller";
      }
    ];
  };

  # Mixed: one non-GPU, then an AMD GPU.
  mixedFacter = {
    hardware.pci_devices = [
      {
        class_id = "0200";
        vendor_name = "Realtek";
        device_name = "RTL8111/8168/8411";
      }
      {
        class_id = "0300";
        vendor_name = "Advanced Micro Devices, Inc. [AMD/ATI]";
        device_name = "Radeon RX 7900 XTX";
      }
    ];
  };

  # Two GPUs: NVIDIA first, AMD second (first wins).
  dualGpuFacter = {
    hardware.pci_devices = [
      {
        class_id = "0300";
        vendor_name = "NVIDIA Corporation";
        device_name = "RTX 4090";
      }
      {
        class_id = "0300";
        vendor_name = "Advanced Micro Devices, Inc. [AMD/ATI]";
        device_name = "RX 7900 XTX";
      }
    ];
  };

  # GPU device with no vendor_name field (missing key).
  noVendorNameFacter = {
    hardware.pci_devices = [
      {
        class_id = "0300";
        device_name = "Mystery GPU";
        # vendor_name is absent
      }
    ];
  };

  runTests = lib.runTests;

in
runTests {

  # ============================================================
  # getPciDevices — extraction with fallback
  # ============================================================

  # Empty facter → empty list.
  testPciDevicesEmptyFacter = {
    expr = getPciDevices emptyFacter;
    expected = [ ];
  };

  # No hardware key → empty list via `or`.
  testPciDevicesNoHardwareKey = {
    expr = getPciDevices { someOtherKey = true; };
    expected = [ ];
  };

  # hardware present but pci_devices absent → empty list.
  testPciDevicesNoPciDevicesKey = {
    expr = getPciDevices { hardware = { cpu = "AMD Ryzen 9"; }; };
    expected = [ ];
  };

  # hardware.pci_devices present → returned verbatim.
  testPciDevicesReturnsList = {
    expr = builtins.length (getPciDevices nvidiaFacter);
    expected = 1;
  };

  # ============================================================
  # getGpuDevices — class_id filter
  # ============================================================

  # class_id "0300" is included.
  testGpuDevicesIncludes0300 = {
    expr = builtins.length (
      getGpuDevices [
        {
          class_id = "0300";
          vendor_name = "NVIDIA";
        }
      ]
    );
    expected = 1;
  };

  # class_id "0302" is included (3D controller).
  testGpuDevicesIncludes0302 = {
    expr = builtins.length (
      getGpuDevices [
        {
          class_id = "0302";
          vendor_name = "NVIDIA";
        }
      ]
    );
    expected = 1;
  };

  # class_id "0200" (network) is excluded.
  testGpuDevicesExcludes0200 = {
    expr = getGpuDevices [
      {
        class_id = "0200";
        vendor_name = "Intel";
      }
    ];
    expected = [ ];
  };

  # class_id "0100" (SCSI controller) is excluded.
  testGpuDevicesExcludes0100 = {
    expr = getGpuDevices [
      {
        class_id = "0100";
        vendor_name = "LSI";
      }
    ];
    expected = [ ];
  };

  # Missing class_id treated as empty string → excluded.
  testGpuDevicesExcludesNoClassId = {
    expr = getGpuDevices [ { vendor_name = "Unknown"; } ];
    expected = [ ];
  };

  # Both 0300 and 0302 in same list → both retained.
  testGpuDevicesBothClassIds = {
    expr = builtins.length (
      getGpuDevices [
        {
          class_id = "0300";
          vendor_name = "Intel";
        }
        {
          class_id = "0302";
          vendor_name = "NVIDIA";
        }
        {
          class_id = "0200";
          vendor_name = "Realtek";
        }
      ]
    );
    expected = 2;
  };

  # Non-GPU facter → empty GPU devices.
  testGpuDevicesFromNonGpuFacter = {
    expr = getGpuDevices (getPciDevices nonGpuFacter);
    expected = [ ];
  };

  # Mixed facter → only the GPU entry is retained.
  testGpuDevicesFromMixedFacter = {
    expr = builtins.length (getGpuDevices (getPciDevices mixedFacter));
    expected = 1;
  };

  # ============================================================
  # getGpuVendor — vendor string, toLower, fallback
  # ============================================================

  # No GPU devices → "unknown".
  testGpuVendorEmptyDevices = {
    expr = getGpuVendor [ ];
    expected = "unknown";
  };

  # NVIDIA vendor → lowercased.
  testGpuVendorNvidiaLowercased = {
    expr = getGpuVendor [
      {
        class_id = "0300";
        vendor_name = "NVIDIA Corporation";
      }
    ];
    expected = "nvidia corporation";
  };

  # AMD vendor → lowercased.
  testGpuVendorAmdLowercased = {
    expr = getGpuVendor [
      {
        class_id = "0300";
        vendor_name = "Advanced Micro Devices, Inc. [AMD/ATI]";
      }
    ];
    expected = "advanced micro devices, inc. [amd/ati]";
  };

  # Intel vendor → lowercased.
  testGpuVendorIntelLowercased = {
    expr = getGpuVendor [
      {
        class_id = "0300";
        vendor_name = "Intel Corporation";
      }
    ];
    expected = "intel corporation";
  };

  # Missing vendor_name → "unknown" (via `or "unknown"`).
  testGpuVendorMissingVendorName = {
    expr = getGpuVendor [ { class_id = "0300"; } ];
    expected = "unknown";
  };

  # First GPU wins when multiple GPUs present.
  testGpuVendorFirstGpuWins = {
    expr = getGpuVendor [
      {
        class_id = "0300";
        vendor_name = "NVIDIA Corporation";
      }
      {
        class_id = "0300";
        vendor_name = "Advanced Micro Devices, Inc. [AMD/ATI]";
      }
    ];
    expected = "nvidia corporation";
  };

  # ============================================================
  # gpuFacts — integrated hasNvidia / hasAmd
  # ============================================================

  # Empty facter → vendor "unknown", hasNvidia false, hasAmd false.
  testGpuFactsEmptyFacter = {
    expr = gpuFacts emptyFacter;
    expected = {
      vendor = "unknown";
      hasNvidia = false;
      hasAmd = false;
    };
  };

  # NVIDIA facter → hasNvidia true, hasAmd false.
  testGpuFactsNvidiaFacter = {
    expr = gpuFacts nvidiaFacter;
    expected = {
      vendor = "nvidia corporation";
      hasNvidia = true;
      hasAmd = false;
    };
  };

  # AMD facter → hasNvidia false, hasAmd true.
  testGpuFactsAmdFacter = {
    expr = (gpuFacts amdFacter).hasAmd;
    expected = true;
  };

  testGpuFactsAmdNotNvidia = {
    expr = (gpuFacts amdFacter).hasNvidia;
    expected = false;
  };

  # Intel facter → neither NVIDIA nor AMD.
  testGpuFactsIntelFacter = {
    expr = gpuFacts intelFacter;
    expected = {
      vendor = "intel corporation";
      hasNvidia = false;
      hasAmd = false;
    };
  };

  # class_id 0302 (3D controller) triggers detection.
  testGpuFactsComputeGpu = {
    expr = (gpuFacts computeGpuFacter).hasNvidia;
    expected = true;
  };

  # Non-GPU PCI devices don't count → unknown.
  testGpuFactsNonGpuDevices = {
    expr = gpuFacts nonGpuFacter;
    expected = {
      vendor = "unknown";
      hasNvidia = false;
      hasAmd = false;
    };
  };

  # Mixed PCI devices: AMD GPU detected despite non-GPU appearing first.
  testGpuFactsMixedDevices = {
    expr = (gpuFacts mixedFacter).hasAmd;
    expected = true;
  };

  # Dual GPU: first GPU (NVIDIA) wins.
  testGpuFactsDualGpuFirstWins = {
    expr = (gpuFacts dualGpuFacter).hasNvidia;
    expected = true;
  };

  testGpuFactsDualGpuSecondIgnored = {
    expr = (gpuFacts dualGpuFacter).hasAmd;
    expected = false;
  };

  # GPU with no vendor_name → "unknown", not an error.
  testGpuFactsMissingVendorName = {
    expr = gpuFacts noVendorNameFacter;
    expected = {
      vendor = "unknown";
      hasNvidia = false;
      hasAmd = false;
    };
  };

  # ============================================================
  # hasInfix edge cases (as used by hasNvidia / hasAmd)
  # ============================================================

  # "nvidia" is a substring of "nvidia corporation".
  testHasInfixNvidiaInFullString = {
    expr = lib.hasInfix "nvidia" "nvidia corporation";
    expected = true;
  };

  # "amd" is a substring of the AMD vendor string.
  testHasInfixAmdInFullString = {
    expr = lib.hasInfix "amd" "advanced micro devices, inc. [amd/ati]";
    expected = true;
  };

  # "nvidia" is NOT in an AMD string.
  testHasInfixNvidiaNotInAmd = {
    expr = lib.hasInfix "nvidia" "advanced micro devices, inc. [amd/ati]";
    expected = false;
  };

  # "amd" is NOT in an NVIDIA string.
  testHasInfixAmdNotInNvidia = {
    expr = lib.hasInfix "amd" "nvidia corporation";
    expected = false;
  };

  # "nvidia" is NOT in "unknown".
  testHasInfixNvidiaNotInUnknown = {
    expr = lib.hasInfix "nvidia" "unknown";
    expected = false;
  };

  # "amd" is NOT in "unknown".
  testHasInfixAmdNotInUnknown = {
    expr = lib.hasInfix "amd" "unknown";
    expected = false;
  };
}
