{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  gvkKeyFn = type: "${type.group}/${type.version}/${type.kind}";
  coerceListOfSubmodulesToAttrs =
    submodule: keyFn:
    let
      mergeValuesByFn =
        keyFn: values: listToAttrs (map (value: nameValuePair (toString (keyFn value)) value) values);

      # Either value of type `finalType` or `coercedType`, the latter is
      # converted to `finalType` using `coerceFunc`.
      coercedTo =
        coercedType: coerceFunc: finalType:
        mkOptionType rec {
          name = "coercedTo";
          description = "${finalType.description} or ${coercedType.description}";
          check = x: finalType.check x || coercedType.check x;
          merge =
            loc: defs:
            let
              coerceVal =
                val:
                if finalType.check val then
                  val
                else
                  let
                    coerced = coerceFunc val;
                  in
                  assert finalType.check coerced;
                  coerced;
            in
            finalType.merge loc (map (def: def // { value = coerceVal def.value; }) defs);
          inherit (finalType) getSubOptions;
          inherit (finalType) getSubModules;
          substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
          typeMerge = _t1: _t2: null;
          functor = (defaultFunctor name) // {
            wrapped = finalType;
          };
        };
    in
    coercedTo (types.listOf (types.submodule submodule)) (mergeValuesByFn keyFn) (
      types.attrsOf (types.submodule submodule)
    );

in
{
  options = {
    definitions = mkOption {
      description = "Attribute set of kubernetes definitions";
    };

    defaults = mkOption {
      description = "Kubernetes defaults to apply to resources";
      type = types.listOf (
        types.submodule (_: {
          options = {
            group = mkOption {
              description = "Group to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            version = mkOption {
              description = "Version to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            kind = mkOption {
              description = "Kind to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            resource = mkOption {
              description = "Resource to apply default to (all by default)";
              type = types.nullOr types.str;
              default = null;
            };

            propagate = mkOption {
              description = "Whether to propagate defaults";
              type = types.bool;
              default = false;
            };

            default = mkOption {
              description = "Default to apply";
              type = types.unspecified;
              default = { };
            };
          };
        })
      );
      default = [ ];
      apply = lib.unique;
    };

    types = mkOption {
      description = "List of registered kubernetes types";
      type = coerceListOfSubmodulesToAttrs {
        options = {
          group = mkOption {
            description = "Resource type group";
            type = types.str;
          };

          version = mkOption {
            description = "Resoruce type version";
            type = types.str;
          };

          kind = mkOption {
            description = "Resource type kind";
            type = types.str;
          };

          name = mkOption {
            description = "Resource type name";
            type = types.nullOr types.str;
          };

          attrName = mkOption {
            description = "Name of the nixified attribute";
            type = types.str;
          };
        };
      } gvkKeyFn;
      default = { };
    };
  };

  config =
    let
      moduleToAttrs =
        value:
        if isAttrs value then
          mapAttrs (_n: moduleToAttrs) (filterAttrs (n: v: v != null && !(hasPrefix "_" n)) value)
        else if isList value then
          map moduleToAttrs value
        else
          value;

      result = mapAttrs (
        _: type:
        lib.mapAttrs' (n: v: rec {
          name = lib.toLower "${n}.${value.kind}";
          value = moduleToAttrs v;
        }) config.resources.${type.group}.${type.version}.${type.kind}
      ) config.types;
    in
    {
      templates = mergeAttrsList (lib.attrValues result);
    };

}
