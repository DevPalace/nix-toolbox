
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

## CI
This is an example how to autogenerate Github Action for EKS:
```nix
{ modules, config, ...}: {

  imports = [
    modules.githubAction
  ];

  ci.github = {
    name = "my-awesome-deployment";
    deploymentAttrPath = config.ci.github.name;
    outputPath = "$PRJ_ROOT/.github/workflows/${config.ci.github.name}.yaml";
    extraDefinitions.permissions = {
      id-token = "write"; # This is required for AWS credentials action
      contents = "read";
    };
    extraSteps = lib.singleton {
      uses = "aws-actions/configure-aws-credentials@v4.0.2";
      "with" = {
        role-to-assume = "\${{ github.ref == 'refs/heads/master' && 'arn:aws:iam::111111111111:role/eks-admin' || 'arn:aws:iam::111111111111:role/eks-devs' }}";
        aws-region = "us-east-1";
      };
    };
  };
}
```
