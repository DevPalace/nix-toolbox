{
  pkgs,
  lib ? pkgs.lib,
}:
let
  mkOptionsMarkdown =
    {
      options,
      filterByFile ? null,
    }:
    let
      definitions = (pkgs.nixosOptionsDoc { inherit options; }).optionsNix;
      json =
        if filterByFile != null then
          lib.filterAttrs (_: v: builtins.elem (toString filterByFile) v.declarations) definitions
        else
          definitions;
      parseDefinition =
        it:
        if builtins.isString it then
          it
        else if it._type == "literalExpression" then
          it.text
        else
          throw "Unknown definition: ${it}";
    in
    pkgs.writeText "options.md" (
      lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (name: value: ''
          ## ${
            builtins.replaceStrings
              [
                "<"
                ">"
              ]
              [
                "\\<"
                "\\>"
              ]
              name
          }

          ${toString value.description}


          **Type:** ${value.type}

          **Default:** `${value.defaultText or parseDefinition (value.default or "")}`

          **Example:**
          ```nix
          ${parseDefinition (value.example or "")}
          ```
        '') json
      )
    );
in
{
  inherit mkOptionsMarkdown;
}
