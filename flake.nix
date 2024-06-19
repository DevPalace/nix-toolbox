{
  inputs.nix2container.url = "github:nlewo/nix2container";

  outputs =
    {
      self,
      nixpkgs,
      nix2container,
    }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      n2c = nix2container.packages.x86_64-linux;
      builder = import ./oci/lib/builder.nix { inherit pkgs n2c; };
    in
    {
      formatter.x86_64-linux = pkgs.nixfmt-rfc-style;
      bluprints.oci.builder = { pkgs }: import ./oci/lib/builder.nix { inherit pkgs n2c; };

      legacyPackages.x86_64-linux.docs = import ./docs { inherit pkgs builder; };
      checks.x86_64-linux = import ./oci/tests { inherit pkgs builder; };
    };
}
