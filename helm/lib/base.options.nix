{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) types literalExpression mkOption;

  kubectl = "${pkgs.kubectl}/bin/kubectl";
  helm = lib.getExe (
    pkgs.wrapHelm pkgs.kubernetes-helm {
      plugins = with pkgs.kubernetes-helmPlugins; [ helm-diff ];
    }
  );

  partitionAttrs =
    fn: values:
    lib.foldlAttrs
      (
        acc: name: value:
        if fn name value then
          {
            inherit (acc) wrong;
            right = acc.right // {
              ${name} = value;
            };
          }
        else
          {
            inherit (acc) right;
            wrong = acc.wrong // {
              "${name}" = value;
            };
          }
      )
      {
        right = { };
        wrong = { };
      }
      values;
in
{
  options = {
    targetName = mkOption {
      description = "Deployment target name";
      type = types.str;
      readOnly = true;
    };

    name = mkOption {
      description = "Name of Helm deployment";
      example = "my-helm-deployment-name";
      type = types.str;
    };

    namespace = mkOption {
      description = "Namespace where chart should be deployed";
      example = "default";
      default = null;
      type = types.nullOr types.str;
    };

    kubeconfig = mkOption {
      description = "Path to $KUBECONFIG. May contain variables like devshell provided $PRJ_ROOT";
      example = "$PRJ_ROOT/.kube/us-east-1";
      default = null;
      type = types.nullOr (types.either types.str types.path);
    };

    context = mkOption {
      description = "KUBECONFIG context to use";
      example = "admin";
      default = null;
      type = types.nullOr types.str;
    };

    chart = mkOption {
      description = "Path to helm Chart.yaml";
      example = literalExpression "./Chart.yaml";
      type = types.path;
    };

    helmArgs = {
      plan = mkOption {
        description = "Helm arguments passed to `plan` action";
        example = [ "--debug" ];
        default = [ ];
        type = types.listOf (types.either types.str types.path);
      };

      apply = mkOption {
        description = "Helm arguments passed to `apply` action";
        example = [ "--debug" ];
        default = [ ];
        type = types.listOf (types.either types.str types.path);
      };

      destroy = mkOption {
        description = "Helm arguments passed to `destroy` action";
        example = [ "--debug" ];
        default = [ ];
        type = types.listOf (types.either types.str types.path);
      };

      status = mkOption {
        description = "Helm arguments passed to `status` action";
        example = [ "--debug" ];
        default = [ ];
        type = types.listOf (types.either types.str types.path);
      };
    };

    copyToRoot = mkOption {
      description = "Files or directories to copy to root of the derivation. Used to pass additional configs";
      type = types.attrsOf types.path;
      default = { };
    };

    templates = mkOption {
      description = "Attrset of Kubernetes resources";
      example = literalExpression ''
        {
          resource-1 = ./path/to/template.yaml;
          resource-2 = {
            apiVersion = "v1";
            kind = "ConfigMap";
            metadata.name = "something";

            data."example.config" = "a = 123";
          };
        }
      '';
      default = { };
      # TODO: Implement better type definition
      type = types.attrsOf (types.either types.path types.anything);
    };

    kustomization = mkOption {
      description = "Kustomize config. Generally used to apply prefixes/labels";
      example = {
        namespace = "default";
        nameprefix = "dev-";
      };
      default = { };
      type = types.anything;
    };

    values = mkOption {
      description = "Helm deployment values";
      example = {
        something.oci.name = "something:v1";
        domain = "example.com";
      };
      default = { };
      type = types.anything;
    };

    utils = mkOption {
      description = "Output derivation containing deployment";
      example = literalExpression ''
        {
          # Converts attribute set to k8s-like env variable definition
          mkPodEnv = lib.mapAttrsToList (
            name: value:
              if (builtins.isString value) || (builtins.isNull value)
              then lib.nameValuePair name value
              else if builtins.isAttrs value
              then value // {inherit name;}
              else throw "Environment variable value can be either string or attribute set"
          );
        }
      '';
      default = { };
      type = types.attrsOf types.anything;
    };

    drv = mkOption {
      description = "Output derivation containing deployment";
      internal = true;
      readOnly = true;
      visible = false;
      type = types.package;
    };
  };

  config =
    let
      output =
        let
          fileNameToEnvVar =
            builtins.replaceStrings
              [
                "."
                "-"
              ]
              [
                "_"
                "_"
              ];
          templates' = lib.mapAttrs' (n: v: {
            name = "${n}.yaml";
            value = if builtins.isPath v then v else builtins.toJSON v;
          }) config.templates;

          mapAttrsToNameEnv = lib.mapAttrs' (n: _: lib.nameValuePair "${fileNameToEnvVar n}Name" n);
          mapAttrsToValueEnv = lib.mapAttrs' (n: v: lib.nameValuePair (fileNameToEnvVar n) v);

          templatesPartitions = partitionAttrs (_: builtins.isPath) (mapAttrsToValueEnv templates');
          templatesNames = mapAttrsToNameEnv templates';

          copyToRootNames = mapAttrsToNameEnv config.copyToRoot;
          copyToRootVars = mapAttrsToValueEnv config.copyToRoot;

          fileTemplates = templatesPartitions.right;
          attrTemplates = templatesPartitions.wrong;

          kustomization' = config.kustomization // {
            resources = [ "resources.yaml" ];
          };

          valuesArgs = [
            "--values"
            "${placeholder "out"}/values.yaml"
            "${placeholder "out"}"
          ];

          bashConfirmationDialog = successCmd: cancelMsg: ''
            echo -e "\n\n\e[1mDo you wish to apply these changes to '\e[34m${config.targetName}\e[0m\e[1m'?\e[0m"
            echo -e "  Only 'yes' will be accepted to approve.\n"
            read -p $'\e[1m  Enter a value: \e[0m' choice
            case "$choice" in
              yes )
                echo
                ${helm} ${successCmd}
              ;;
              * ) echo -e '\n${cancelMsg}'; exit 1;;
            esac
          '';

          # Helm Commands
          __commandApply = ''
            #! ${pkgs.bash}/bin/sh
            cd ${placeholder "out"}
            ${placeholder "out"}/bin/plan.sh
            ${bashConfirmationDialog "upgrade --install ${config.name} ${toString (config.helmArgs.apply ++ valuesArgs)}" "Apply canceled"}
          '';

          __commandDestroy = ''
            #! ${pkgs.bash}/bin/sh
            ${bashConfirmationDialog "uninstall ${config.name} ${toString config.helmArgs.destroy}" "Destroy canceled"}
          '';

          __commandPlan = ''
            #! ${pkgs.bash}/bin/sh
            cd ${placeholder "out"}
            ${helm} diff upgrade ${config.name} --install  ${toString (config.helmArgs.plan ++ valuesArgs)}
          '';

          __commandStatus = ''
            #! ${pkgs.bash}/bin/sh
            ${helm} status ${config.name} ${toString config.helmArgs.status}
          '';

        in
        derivation (
          {
            name = lib.strings.sanitizeDerivationName config.name;
            inherit (pkgs) system;
            builder = "${pkgs.bash}/bin/sh";
            args = [ ./nix-helm.builder.sh ];
            __ignoreNulls = true;
            preferLocalBuild = true;
            allowSubstitutes = false;

            # Derivation specific config
            PATH = lib.makeBinPath [
              pkgs.coreutils
              pkgs.gojsontoyaml
            ];

            inherit
              __commandApply
              __commandDestroy
              __commandPlan
              __commandStatus
              ;
            chartPath = config.chart;
            #chart = if chart == null then null else builtins.toJSON chart;
            values = builtins.toJSON config.values;

            passAsFile = [
              "__commandApply"
              "__commandDestroy"
              "__commandPlan"
              "__commandStatus"
              "values"
            ] ++ builtins.attrNames attrTemplates;
            attrTemplates = builtins.attrNames attrTemplates;
            fileTemplates = builtins.attrNames fileTemplates;
            copyToRoot = builtins.attrNames copyToRootVars;
          }
          // fileTemplates
          // attrTemplates
          // templatesNames
          // copyToRootVars
          // copyToRootNames
          // (lib.optionalAttrs (config.kustomization != { }) {
            kustomization = builtins.toJSON kustomization';
          })
        );

      mkAction = execName: {
        inherit (output)
          drvPath
          type
          outPath
          outputName
          name
          ;
        meta.mainProgram = execName;
      };

      postRenderer = pkgs.writeShellScript "kustomize.sh" ''
        set -euo pipefail
        TMP=$(mktemp -d)
        cat > $TMP/resources.yaml
        cp kustomization.yaml $TMP/kustomization.yaml
        ${kubectl} kustomize $TMP
        rm -r $TMP
      '';

      commonHelmArgs =
        lib.optionals (config.namespace != null) [
          "--namespace"
          config.namespace
        ]
        ++ lib.optionals (config.kubeconfig != null) [
          "--kubeconfig"
          config.kubeconfig
        ]
        ++ lib.optionals (config.context != null) [
          "--kube-context"
          config.context
        ];

      helmArgsWithRenderer =
        commonHelmArgs
        ++ lib.optionals (config.kustomization != { }) [
          "--post-renderer"
          postRenderer
        ];
    in
    {
      _module.args = {
        inherit (config) utils values;
      };

      helmArgs = {
        plan = helmArgsWithRenderer;
        apply = helmArgsWithRenderer;
        destroy = commonHelmArgs;
        status = commonHelmArgs;
      };

      drv = {
        inherit (output) drvPath type;
        apply = mkAction "apply.sh";
        destroy = mkAction "destroy.sh";
        plan = mkAction "plan.sh";
        status = mkAction "status.sh";
      };
    };
}
