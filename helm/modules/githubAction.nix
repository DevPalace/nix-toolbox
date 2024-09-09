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
          required = true;
        };
        action = {
          type = "string";
          required = true;
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
            run = ''
              echo "yes" | nix run .#${cfg.deploymentAttrPath}.''${{inputs.target}}.''${{inputs.action}}
            '';
          }
        ];
    };
  } cfg.extraDefinitions;
  yaml = pkgs.writers.writeYAML "github-action" job;
in
{
  options.ci.github = {
    name = lib.mkOption {
      type = types.string;
      description = "Name of Github Action";
      example = lib.literalExpression "my-awesome-deployment";
    };

    deploymentAttrPath = lib.mkOption {
      type = types.string;
      description = "Attribute path to the deployment";
      example = lib.literalExpression "my-awesome-deployment";
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
      type = types.string;
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
