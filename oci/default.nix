{ inputs, ... }:
{

  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      n2c = inputs.nix2container.packages.${system};
    in
    rec {
      legacyPackages.oci = {
        builder = import ./lib/builder.nix { inherit pkgs n2c; };
        docs = import ../docs {
          inherit pkgs;
          inherit (legacyPackages.oci) builder;
        };
      };
      checks = import ./tests {
        inherit pkgs;
        inherit (legacyPackages.oci) builder;
      };
    };
}
