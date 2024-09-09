{ modules, lib, ... }:
{
  imports = [
    modules.githubAction
  ];

  ci.github = {
    name = "nginx-example";
    deploymentAttrPath = "helm.examples.nginx";
    extraSteps = lib.singleton {
      name = "Start k8s cluster";
      run = "nix run .#createK8sCluster";
    };
  };
}
