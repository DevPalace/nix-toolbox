{
  pkgs,
  lib,
  config,
  self,
  ...
}:
let
  inherit (lib) types;
  cfg = config.ci.github;
  targets = lib.attrNames (lib.filterAttrs (_: v: (v.config.chart or null) != null) self);
  job = lib.recursiveUpdate {
    inherit (cfg) name;
    on = {
      workflow_dispatch.inputs = {
        target = {
          description = "Targets";
          type = "choice";
          required = true;
          options = targets;
        };
        action = {
          description = "Action";
          type = "choice";
          required = true;
          options = [
            "apply"
            "destroy"
            "plan"
          ];
        };
      };

      workflow_call.inputs = {
        target = {
          type = "string";
        };
        action = {
          type = "string";
        };
        targetsToDiff = {
          type = "string";
        };
      };
    };

    jobs.deploy = {
      environment = "\${{ inputs.environment }}";
      runs-on = "ubuntu-latest";
      steps =
        [
          {
            name = "📥 Checkout repository";
            uses = "actions/checkout@v3";
          }
          {
            name = "🧰 Setup Nix";
            uses = "nixbuild/nix-quick-install-action@v28";
          }
        ]
        ++ cfg.extraSteps
        ++ [
          {
            name = "🚀 Deploy";
            uses = "./ci/helm";
            "with" = {
              inherit (cfg) deploymentAttrPath;
              target = "\${{inputs.target}}";
              action = "\${{inputs.action}}";
              targetsToDiff = lib.concatStringsSep "," cfg.targetsToDiff;
            };
          }
        ];
    };
  } cfg.extraDefinitions;
  yaml = pkgs.writers.writeYAML "github-action" job;
in
{
  options.ci.github = {
    name = lib.mkOption {
      type = types.str;
      description = "Name of Github Action";
      example = lib.literalExpression "my-awesome-deployment";
    };

    deploymentAttrPath = lib.mkOption {
      type = types.str;
      description = "Attribute path to the deployment";
      example = lib.literalExpression "my-awesome-deployment";
    };

    targetsToDiff = lib.mkOption {
      type = types.listOf types.str;
      description = "List of target names to post diff on pull requests";
      example = lib.literalExpression "[\"target-name-1\" \"target-name-2\"]";
    };

    extraSteps = lib.mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = ''
        Additional Github Action steps to run before executing target.
        Usually used for k8s authentification.
      '';
      example = lib.literalExpression ''
        lib.singleton {
          uses = "aws-actions/configure-aws-credentials@v4.0.2";
          "with" = {
            role-to-assume = "\''${{ github.ref == 'refs/heads/master' && 'arn:aws:iam::111111111111:role/eks-admin' || 'arn:aws:iam::111111111111:role/eks-devs' }}";
            aws-region = "us-east-1";
          };
        };
      '';
    };

    extraDefinitions = lib.mkOption {
      type = types.attrs;
      description = "Extra Github Action overrides";
      default = { };
      example = lib.literalExpression ''
        permissions = {
          id-token = "write"; # This is required for AWS credentials action
          contents = "read";
        };
      '';
    };

    outputPath = lib.mkOption {
      type = types.str;
      description = "Github Action output path";
      default = "$PRJ_ROOT/.github/workflows/${config.ci.github.name}.yaml";
      defaultText = lib.literalExpression "$PRJ_ROOT/.github/workflows/\${config.ci.github.name}.yaml";
    };

  };
  config = {

    hooks.pre = ''
      mkdir -p $(dirname ${cfg.outputPath})
      cp -f ${yaml} ${cfg.outputPath}
    '';
  };
}
