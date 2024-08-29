{
  pkgs,
  lib ? pkgs.lib,
  nix-toolbox,
}:
let
  mkHelm = pkgs.callPackage nix-toolbox.blueprints.mkHelm { inherit pkgs; };
in
mkHelm {
  defaults = final: {
    name = "${final.targetName}-example"; # Use target name as prefix for helm chart name
    chart = ./Chart.yaml;
    namespace = "default"; # Optional but recommended
    context = "kind-kind"; # Optional but recommended
    kubeconfig = "$KUBECONFIG"; # Optional but recommended

    # Import resources to be deployed, alternativelly everything can be defined in the same file
    imports = [
      ./resources.nix
    ];

    kustomization = {
      inherit (final) namespace; # Explicitly set `metadata.namespace` to resources using kustomize
      namePrefix = "${final.targetName}-"; # Prefix target name to each resource name
    };

    # Tell helm to create namespace if necessary
    helmArgs.apply = [ "--create-namespace" ];

    # We can define functions to be used in our deployments. This one is used in ./resources.nix
    utils.mkPodResources = memory: cpu: { inherit memory cpu; };

    # Default values
    values = {
      nginx.image = "some-default-value";
    };
  };

  targets = {
    prod = final: {
      namespace = "prod-nginx"; # Same pattern could be used as for setting the chart name in defaults

      # Overwriting resource definition from ./resources.nix
      resources.deployments.nginx.spec.template.spec.containers.nginx.resources = lib.mkForce {
        limits = final.utils.mkPodResources "300Mi" "300m";
        requests = final.utils.mkPodResources "200Mi" "200m";
      };

      values = {
        nginx.image = "nginx:1.27.1";
      };
    };

    dev = final: {
      namespace = "dev-nginx";
      values = {
        nginx.image = "nginx:latest";
      };
    };
  };
}
