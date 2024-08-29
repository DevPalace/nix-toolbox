{
  lib,
  utils,
  values,
  config,
  ...
}:
{
  resources = {
    ingresses.nginx.spec.rules = [
      {
        http = {
          paths = [
            {
              pathType = "Prefix";
              path = "/";
              backend.service = {
                name = "${config.targetName}-nginx";
                port.name = "http";
              };
            }
          ];
        };
      }
    ];

    services.nginx.spec = {
      selector.app = "nginx";
      ports.http = {
        name = "http";
        protocol = "TCP";
        port = 80;
        targetPort = "http";
      };
    };

    deployments.nginx.spec = {
      selector.matchLabels.app = "nginx";
      template = {
        metadata.labels.app = "nginx";
        spec.containers.nginx = {
          image = values.nginx.image;
          ports.http.containerPort = 80;
          resources = {
            limits = utils.mkPodResources "200Mi" "200m";
            requests = utils.mkPodResources "100Mi" "100m";
          };
        };
      };
    };
  };
}
