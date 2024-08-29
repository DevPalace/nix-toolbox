
# helm

A Kubernetes deployment management tool powered by Nix.

## Motivation

Working with Helm templating can be messy and annoying. Utilizing a Turing complete language like Nix offers a more convenient and powerful approach for managing Kubernetes deployments.

## Features

- **Flexible Resource Definitions**: Define resources using either YAML or Nix expressions, allowing for a more versatile and expressive configuration.
- **Deployment Planning**: Plan deployments by diffing against the current state, ensuring you know exactly what changes will be applied.
- **Targeted Deployments**: Define deployment targets without the need for additional tools like `helmfile`.
- **Custom Resource Definitions**: Leverage the power of the Nix modules system to define custom resources which get converted down to standard K8s resources
- **Resource Overrides**: Use Kustomize-like resource overrides to customize and manage your Kubernetes resources easily.


## Play with it!
```bash
nix run .\#createK8sCluster # Starts K8s cluster in docker
nix run .\#helm.examples.nginx.prod.apply # Installs example chart
curl localhost # Should result in nginx homepage

```

