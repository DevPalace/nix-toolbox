{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./internal/blueprints.nix
        ./oci
        ./helm
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          pkgs,
          lib,
          system,
          self',
          ...
        }:
        {

          formatter = pkgs.nixfmt-rfc-style;

          packages.docs =
            let

              summary = pkgs.writeText "options.md" ''
                # Summary

                - [OCI](./oci.md)
                  - [Options Reference](./oci.md)
                - [Helm](./helm.md)
                   ${helmDocs}
              '';

              helmDocs = toString (
                lib.mapAttrsToList (
                  n: drv: "- [${n}](./helm/${n}.md)\n  "
                ) self'.legacyPackages.helm.k8sResourceDocs
              );
              cpHelmDocs = toString (
                lib.mapAttrsToList (
                  n: drv: "cp -f ${drv} src/helm/${n}.md\n"
                ) self'.legacyPackages.helm.k8sResourceDocs
              );
            in
            pkgs.writeShellScriptBin "build-mdbook.sh" ''
              cd docs
              rm -rf src
              mkdir -p src/helm
              touch src/helm.md
              cp ${summary} src/SUMMARY.md
              cp ${self'.legacyPackages.oci.docs} src/oci.md
              ${cpHelmDocs}
              ${lib.getExe pkgs.mdbook} build
            '';
        };
    };
}
