{ inputs, ... }:
{

  perSystem =
    {
      pkgs,
      system,
      self',
      ...
    }:
    let
      n2c = inputs.nix2container.packages.${system};
    in
    rec {
      legacyPackages.oci = {
        builder = import ./lib/builder.nix { inherit pkgs n2c; };
        docs =
          (pkgs.nixosOptionsDoc {
            warningsAreErrors = false;
            options = self'.checks.usersAndPerms.image.options;
          }).optionsCommonMark;
      };
      checks = import ./tests {
        inherit pkgs;
        inherit (legacyPackages.oci) builder;
      };
    };
}
