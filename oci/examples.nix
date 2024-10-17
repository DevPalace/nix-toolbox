{
  pkgs,
  lib ? pkgs.lib,
  builder,
}:
{
  nix = builder {
    name = "nix";
    imports = [ ./modules/cacert.nix ];
    nix.initializeDatabase = true;

    packages = with pkgs; [
      coreutils
      nix
      bashInteractive
    ];
    directories."/tmp".mode = "1777";
    #maxLayers = 128;

    files."/etc/nix/nix.conf".text = ''
      allowed-users = *
      auto-optimise-store = true
      cores = 64
      max-jobs = 64
      http-connections = 50
      http2 = true
      allow-import-from-derivation = true
      extra-experimental-features = nix-command flakes
    '';

    env = {
      NIX_PAGER = "cat";
      USER = "nobody";
    };
  };
}
