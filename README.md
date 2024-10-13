
# Nix Toolbox

Welcome to the Nix Toolbox! This project serves as a toolbox for all your deployment needs :)

## Features

Nix Toolbox currently supports the following features:

- **Helm Deployments**: Easily deploy your applications using Helm. Check out the `helm` directory for more details and examples.

- **OCI Image Building**: Build OCI-compliant images with ease. The `oci` directory contains all the necessary information and instructions to get you started.

## Getting Started

To begin using the Nix Toolbox, create a flake as follows. Output definitions are mentioned in the `helm` and `oci` directories:

```nix
{
  description = "My awesome flake";

  inputs = {
    nix-toolbox = {
      url = "github:DevPalace/nix-toolbox";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # Uncomment this line if you are using flake-parts
        # flake-parts.follows = "flake-parts";

        # Uncomment this line if aren't using `oci` integration
        # nix2container.follows = "";
      };
    };

  };

```

## Contributing

We welcome contributions from the community! If you have an idea for a new feature or improvement, feel free to submit a pull request or open an issue on GitHub.


## Contact

For questions or support, please reach out via:
- GitHub Issues: [Open an Issue](https://github.com/DevPalace/nix-toolbox/issues)
- Email: [me@gytis.io](mailto:me@gytis.io)
- Discord: `@gytis.iva`

Happy Nixing!
