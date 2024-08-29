{
  inputs,
  lib,
  self,
  ...
}:
{

  flake.blueprints.mkHelm =
    {
      pkgs,
      lib ? pkgs.lib,
    }:
    import ./lib { inherit pkgs lib; };

  perSystem =
    {
      pkgs,
      system,
      self',
      ...
    }:
    let
      docs = import ./docs.nix {
        inherit pkgs;
        deployment = self'.legacyPackages.helm.examples.nginx.prod;
      };
    in
    rec {

      apps.updateHelmGeneratedFiles.program = pkgs.writers.writeBashBin "update-helm-generated-files" ''
        RESULT_DIR="$(git rev-parse --show-toplevel)/helm/generated"
        WORK_DIR=$(mktemp -d)
        cd $WORK_DIR

        git clone --depth=1  https://github.com/hall/kubenix/
        cp -Rf kubenix/modules/generated/* $RESULT_DIR

        rm -rf $WORK_DIR
      '';

      apps.createK8sCluster.program = pkgs.writers.writeBashBin "create-kind-cluster" ''
        ${lib.getExe pkgs.kind} create cluster --kubeconfig $KUBECONFIG --config=${./kind.yaml}
        ${lib.getExe pkgs.kubectl} apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
      '';

      legacyPackages.helm = {
        inherit (docs) k8sResourceDocs wrapperDocs;
        examples.nginx = import ./examples/nginx {
          inherit pkgs;
          nix-toolbox = self;
        };
      };

    };
}
