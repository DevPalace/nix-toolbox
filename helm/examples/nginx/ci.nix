{ modules, lib, ... }:
{
  imports = [
    modules.githubAction
  ];

  ci.github = {
    name = "nginx-example";
    deploymentAttrPath = "helm.examples.nginx";
    extraDefinitions = {
      on.pull_request = null;
      permissions = {
        contents = "read";
        pull-requests = "write";
      };
    };
    targetsToDiff = ["dev" "prod"];
    extraSteps = lib.singleton {
      name = "Start k8s cluster";
      run = "nix run .#createK8sCluster";
    };
  };
}
