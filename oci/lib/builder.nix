{
  n2c,
  pkgs,
  lib ? pkgs.lib,
}:

with lib;
config:
let
  result = evalModules {
    modules = [
      ./wrapper.options.nix
      ./packages.options.nix
      ./files.options.nix
      ./users.options.nix
      config
    ];
    specialArgs = {
      inherit pkgs n2c;
      modules = {
        cacerts = ../modules/cacert.nix;
      };
    };
  };
in
{
  inherit (result.config.drv)
    type
    outputs
    out
    outPath
    drvPath
    system
    meta
    outputName
    ;
  inherit (result.config)
    drv
    name
    tag
    tags
    ;
  inherit (result) config options;
}
// result.config.passthru
