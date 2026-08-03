{
  pkgs,
  lib,
  config,
  ...
}:

################################################################################
# 3D PRINTING / CAD TOOLSET (Home Manager)
################################################################################
#
# ft.cad3d — a slicing and modeling toolset for FDM 3D printing. OrcaSlicer
# ships Klipper-aware profiles (including Creality K2) out of the box, so no
# separate host-side Klipper/Moonraker setup is needed here — the printer's
# own board runs that. Everything else covers the design side: parametric and
# mesh CAD, vector art, and STL inspection/repair before slicing.

let
  cfg = config.ft.cad3d;
in
{
  options.ft.cad3d = {
    enable = lib.mkEnableOption "3D printing and CAD toolset" // {
      description = "Installs a 3D printing and CAD toolset for slicing and modeling: OrcaSlicer, Blender, FreeCAD, OpenSCAD, Inkscape, MeshLab, and f3d. OrcaSlicer's Creality K2 profiles cover Klipper-based slicing out of the box; the rest cover parametric/mesh modeling, vector art, and STL cleanup before slicing.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Not wrapped in lib.mkDefault: home.packages is a list option, and
    # ft.terminal (enabled by default) sets it at normal priority. A
    # mkDefault'd list here would be discarded wholesale rather than merged
    # whenever another module also contributes to home.packages — see the
    # module-authoring rules on list/attrset options.
    home.packages = with pkgs; [
      orca-slicer
      blender
      freecad
      openscad
      inkscape
      meshlab
      f3d
    ];
  };
}
