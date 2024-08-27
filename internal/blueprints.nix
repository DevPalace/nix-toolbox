{ lib, flake-parts-lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (flake-parts-lib)
    mkSubmoduleOptions
    ;
in
{
  options.flake = mkSubmoduleOptions {
      blueprints = mkOption {
        type = types.attrsOf types.unspecified ;
        default = { };
        example = lib.literalExpression or lib.literalExample ''
          {
            something = {lib, pkgs, coreutils}: coreutils;
          }
        '';
        description = ''
          An attribute set of blueprints.

          Blueprints are functions which take arguments that can be passed via `pkgs.callPackage` and result in one of the following:
          - Derivation
          - Function which results in derivation
          - Attribute set of something. Typically at some point of nesting results in either a derivation or function
        '';
      };
    };
}
