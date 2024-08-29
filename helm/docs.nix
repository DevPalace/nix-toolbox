{
  pkgs,
  lib ? pkgs.lib,
  deployment,
}:
let
  mkDocs =
    options:
    (pkgs.nixosOptionsDoc {
      warningsAreErrors = false;
      inherit options;
    }).optionsCommonMark;

  baseModuleEval = lib.evalModules {
    modules = [
      ./lib/base.options.nix
    ];
    specialArgs = {
      inherit pkgs;
    };
  };

  inherit (deployment.options) resources;
  # Ignores non aliased resources
  # Also ignores `customResourceDefinitions` since otherwise parser crashes
  resourceOptions = lib.filterAttrs (
    n: _:
    !(lib.hasSuffix "k8s.io" n)
    && !(lib.elem n [
      "apps"
      "core"
      "batch"
      "customResourceDefinitions"
    ])
  ) resources;
  resourceNameToMdDocs = lib.mapAttrs (n: _: mkDocs resources.${n}) resourceOptions;
in
{
  k8sResourceDocs = pkgs.runCommand "helm-resources-docs" { } ''
    mkdir $out
    ${toString (lib.mapAttrsToList (n: drv: "cp ${drv} $out/${n}.md\n") resourceNameToMdDocs)}
  '';

  wrapperDocs = mkDocs baseModuleEval.options;
}
