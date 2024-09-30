{
  inputs,
  lib,
  self,
  ...
}:
{

  flake.blueprints = {
    mkHelm =
      {
        pkgs,
        lib ? pkgs.lib,
      }:
      import ./lib { inherit pkgs lib; };
  };

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
        export PRJ_ROOT="$(git rev-parse --show-toplevel)"
        source $PRJ_ROOT/.envrc
        if [[ -n "''${GITHUB_ENV}" ]]; then
          echo "KUBECONFIG=$KUBECONFIG" >> $GITHUB_ENV
          echo "PRJ_ROOT=$PRJ_ROOT" >> $GITHUB_ENV
        fi
        export PATH=$PATH:${pkgs.kubectl}/bin

        ${lib.getExe pkgs.kind} create cluster --kubeconfig $KUBECONFIG --config=${./kind.yaml}
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        sleep 10
        echo Waiting for nginx to be ready
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=90s
      '';

      legacyPackages.helm = {
        inherit (docs) k8sResourceDocs wrapperDocs k8sResourceDocsAll;
        mkHelm = self.blueprints.mkHelm { inherit pkgs; };
        examples.nginx = import ./examples/nginx {
          inherit pkgs;
          nix-toolbox = self;
        };
      };

    };
}
