{
  pkgs,
  lib,
  config,
  n2c,
  ...
}:
let
  inherit (lib) mkOption types literalExample;
  inherit (lib.types)
    str
    nullOr
    attrs
    attrsOf
    listOf
    bool
    either
    int
    package
    ;
in
{
  options = {
    name = mkOption {
      type = str;
      description = ''
        The name of the image.
      '';
    };

    tag = mkOption {
      type = str;
      readOnly = true;
      description = ''
        Unique image tag
      '';
    };

    tags = mkOption {
      default = [ ];
      type = listOf str;
      description = ''
        Additional tags of the image
      '';
    };

    actions = mkOption {
      type = attrsOf str;
      default = { };
      description = ''
        Actions which could be performed on derivation
      '';
    };

    meta = mkOption {
      type = attrs;
      default = { };
      description = ''
        Metadata of image
      '';
    };

    passthru = mkOption {
      type = attrs;
      default = { };
      description = ''
        Extra attributes of image
      '';
    };

    drv = mkOption {
      type = types.package;
      description = "This option contains the store path that represents container.";
      readOnly = true;
      visible = false;
    };

    fromImage = mkOption {
      type = either str package;
      default = "";
      description = ''
        An image that is used as base image of this image.
      '';
    };

    nix = {
      initializeDatabase = mkOption {
        type = bool;
        default = false;
        description = ''
          To initialize the Nix database with all store paths added into the image.
          Note this is only useful to run nix commands from the image, for instance to build an image used by a CI to run Nix builds.
        '';
      };

      uid = mkOption {
        type = int;
        default = 0;
        description = ''
          If nix.initializeDatabase is set to true, the uid of /nix can be controlled using nix.uid
        '';
      };

      gid = mkOption {
        type = int;
        default = 0;
        description = ''
          If nix.initializeDatabase is set to true, the gid of /nix can be controlled using nix.gid
        '';
      };
    };

    # Config https://github.com/opencontainers/image-spec/blob/8b9d41f48198a7d6d0a5c1a12dc2d1f7f47fc97f/specs-go/v1/config.go#L23
    user = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Username or UID which the process in the container should run as.
      '';
    };

    exposedPorts = mkOption {
      type = attrs;
      default = { };
      description = ''
        A set of ports to expose from a container running this image.
      '';
      example = literalExample ''
        { "8080/tcp" = {}; };
      '';
    };

    env = mkOption {
      type = attrs;
      default = { };
      description = ''
        Environment variables to be used in a container.
      '';
    };

    entrypoint = mkOption {
      type = either (either str package) (listOf (either str package));
      default = [ ];
      apply = it: if lib.isList it then it else [it];
      description = ''
        A list of arguments to use as the command to execute when the container starts.
      '';
    };

    cmd = mkOption {
      type = listOf (either str package);
      default = [ ];
      description = ''
        The default arguments to the entrypoint of the container.
      '';
    };

    volumes = mkOption {
      #	Volumes map[string]struct{} `json:"Volumes,omitempty"`
      type = attrs;
      default = { };
      description = ''
        Set of directories describing where the process is likely write data specific to a container instance.
      '';
    };

    workingDir = mkOption {
      type = str;
      default = "/";
      description = ''
        Sets the current working directory of the entrypoint process in the container.
      '';
    };

    labels = mkOption {
      #	Labels map[string]string `json:"Labels,omitempty"`
      type = attrsOf str;
      default = { };
      description = ''
        Arbitrary metadata for the container.
      '';
    };

    stopSignal = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        The system call signal that will be sent to the container to exit.
      '';
    };
  };

  config =
    let
      # Nest all layers so that prior layers are dependencies of later layers.
      # This way, we should avoid redundant dependencies.
      foldImageLayers =
        let
          mergeToLayer =
            priorLayers: component:
            assert builtins.isList priorLayers;
            assert builtins.isAttrs component;
            let
              layer = n2c.nix2container.buildLayer (component // { layers = priorLayers; });
            in
            priorLayers ++ [ layer ];
        in
        layers: lib.foldl mergeToLayer [ ] layers;

      tags = builtins.toFile (lib.strings.sanitizeDerivationName "${config.name}-tags") (
        builtins.unsafeDiscardStringContext (builtins.concatStringsSep "\n" ([ config.tag ] ++ config.tags))
      );

      copyFn = ''
        export PATH=$PATH:${lib.makeBinPath [ n2c.skopeo-nix2container ]}

        copy() {
          local uri prev_tag
          uri=$1
          shift

          for tag in $(<${tags}); do
            if ! [[ -v prev_tag ]]; then
              skopeo --insecure-policy copy nix:${config.drv} "$uri:$tag" "$@"
            else
              # speedup: copy from the previous tag to avoid superflous network bandwidth
              skopeo --insecure-policy copy "$uri:$prev_tag" "$uri:$tag" "$@"
            fi
            echo -e "Done: $uri:$tag\n"

            prev_tag="$tag"
          done
        }
      '';
    in
    {
      tag = config.drv.imageTag;
      passthru = {
        imageRefUnsafe = builtins.unsafeDiscardStringContext "${config.name}:${config.tag}";
      } // (lib.mapAttrs (n: pkgs.writeShellScriptBin n) config.actions);

      drv = n2c.nix2container.buildImage {
        inherit (config)
          name
          copyToRoot
          fromImage
          maxLayers
          perms
          ;

        initializeNixDatabase = config.nix.initializeDatabase;
        nixUid = config.nix.uid;
        nixGid = config.nix.gid;

        layers = foldImageLayers config.layers;

        config =
          {
            WorkingDir = config.workingDir;
          }
          // (lib.optionalAttrs (config.user != null) { User = config.user; })
          // (lib.optionalAttrs (config.exposedPorts != { }) { ExposedPorts = config.exposedPorts; })
          // (lib.optionalAttrs (config.env != { }) {
            Env = lib.mapAttrsToList (n: v: "${n}=${v}") config.env;
          })
          // (lib.optionalAttrs (config.entrypoint != [ ]) { Entrypoint = config.entrypoint; })
          // (lib.optionalAttrs (config.cmd != [ ]) { Cmd = config.cmd; })
          // (lib.optionalAttrs (config.volumes != { }) { Volumes = config.volumes; })
          // (lib.optionalAttrs (config.labels != { }) { Labels = config.labels; })
          // (lib.optionalAttrs (config.stopSignal != null) { StopSignal = config.stopSignal; });
      };

      actions.print-image = ''
        echo
        for tag in $(<${tags}); do
          echo "${config.name}:$tag"
        done
      '';

      actions.load = ''
        ${copyFn}
        if command -v podman &> /dev/null; then
           echo "Podman detected: copy to local podman"
           copy containers-storage:${config.name} "$@"
        fi
        if command -v docker &> /dev/null; then
           echo "Docker detected: copy to local docker"
           copy docker-daemon:${config.name} "$@"
        fi
      '';

      actions.publish = ''
        ${copyFn}
        copy docker://${config.name}
      '';
    };
}
