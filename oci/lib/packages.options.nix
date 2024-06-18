{
  pkgs,
  n2c,
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkOption
    types
    literalExample
    concatMapStringsSep
    escapeShellArgs
    filter
    attrValues
    literalExpression
    mkIf
    mkDerivedConfig
    mkDefault
    ;
  inherit (lib.types)
    str
    nullOr
    attrs
    attrsOf
    listOf
    bool
    either
    int
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
