{ pkgs, lib }:
{
  name ? deploymentAttrPath,
  deploymentAttrPath,
  deployment,
  extraSteps ? [ ],
  extraDefinitions ? { },
  outputPath,
}:
let
  targets = lib.attrNames (lib.filterAttrs (_: v: (v.config.chart or null) != null) deployment);
  job = lib.recursiveUpdate {
    inherit name;
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
        ++ extraSteps
        ++ [
          {
            name = "🚀 Deploy";
            run = ''
              echo "yes" | nix run .#${deploymentAttrPath}.''${{inputs.target}}.''${{inputs.action}}
            '';
          }
        ];
    };
  } extraDefinitions;
  yaml = pkgs.writers.writeYAML "github-action" job;
in
''
  cp -f ${yaml} ${outputPath}
''
