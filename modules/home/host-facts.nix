{ config, lib, inputs, ... }:

let
  h         = config.ft.primaryHost;
  factsFile = inputs.self + "/var/${h}/facts.nix";
  hostFacts = if h != "" && builtins.pathExists factsFile then import factsFile else {};
in {
  options.ft.hostFacts = lib.mkOption {
    type        = lib.types.attrsOf lib.types.anything;
    default     = {};
    readOnly    = true;
    description = "Host facts imported from var/<primaryHost>/facts.nix at eval time.";
  };

  config.ft.hostFacts = hostFacts;
}
