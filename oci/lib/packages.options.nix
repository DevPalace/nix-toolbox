{
  pkgs,
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkOption
    types
    mkIf
    ;
  inherit (lib.types)
    listOf
    package
    ;
in
{
  options = {
    packages = mkOption {
      type = listOf package;
      default = [ ];
      description = ''
        List of packages to link to /bin
      '';
    };
  };

  config = {
    setup.packages = lib.mkIf (config.packages != [ ]) {
      drv = pkgs.buildEnv {
        name = "packages";
        paths = config.packages;
        pathsToLink = [ "/bin" ];
      };
    };

    setup.bin-as-dir-fix = lib.mkIf (config.packages != [ ]) {
      drv = pkgs.runCommandLocal "bin" { } "mkdir -p $out/bin";
    };
  };
}
