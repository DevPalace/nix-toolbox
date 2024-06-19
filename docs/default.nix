{
  pkgs,
  lib ? pkgs.lib,
  builder,
}:
let
  genDocs = import ../gen-docs { inherit pkgs; };
  inherit (builder { name = "docs"; }) options;

  docs = {
    all = genDocs.mkOptionsMarkdown { inherit options; };
  };

  summary = pkgs.writeText "options.md" ''
    # Summary

    - [OCI](./oci.md)
  '';
in
pkgs.writeShellScriptBin "build-mdbook.sh" ''
  cd docs
  rm -rf src
  mkdir -p src
  cp ${summary} src/SUMMARY.md
  cp ${docs.all} src/oci.md
  ${lib.getExe pkgs.mdbook} build
''
