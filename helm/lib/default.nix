{
  pkgs,
  lib ? pkgs.lib,
}:
let
  mkHelm =
    {
      k8sVersion ? "1.30",
      defaults ? _: { },
      targets,
      targetGroups ? _: { },
    }:
    let
      chartConstructor =
        name: target:
        let
          args = lib.recursiveUpdate (defaults args) ({ targetName = name; } // (target args));
          eval = lib.evalModules {
            modules = [
              ./base.options.nix
              ./resource.options.nix
              (../generated + "/v${k8sVersion}.nix")
              args
            ];
            specialArgs = {
              inherit pkgs;
            };
          };
        in
        eval.config.drv // { inherit (eval) options config; };

      deployments = lib.mapAttrs chartConstructor targets;
      mkAllScript =
        targets: scriptKey:
        pkgs.writers.writeBashBin "all-${scriptKey}.sh" (
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: ''
              echo -e "\n\n\e[1m—————————————————————————————————————————————————————————\e[0m"
              echo -e "\e[1mExecuting ${scriptKey} on '\e[34m${name}\e[0m\e[1m':\e[0m\n"
              ${value.${scriptKey}}/bin/${value.${scriptKey}.meta.mainProgram}
            '') (lib.mapAttrs chartConstructor targets)
          )
        );
      targetGroups' = (targetGroups targets) // {
        ALL = targets;
      };
    in
    deployments
    // (lib.mapAttrs (name: targets: {
      apply = mkAllScript targets "apply";
      destroy = mkAllScript targets "destroy";
      plan = mkAllScript targets "plan";
      status = mkAllScript targets "status";
    }) targetGroups');
in
mkHelm
