{ pkgs, n2c, config, lib, ... }:


let
  inherit (lib) attrNames mkOption types literalExample concatMapStringsSep escapeShellArgs filter attrValues literalExpression mkIf mkDerivedConfig mkDefault mapAttrsToList;
  inherit (lib.types) str nullOr attrs attrsOf listOf bool either int package submodule;
in
{
  options = {
    copyToRoot = mkOption {
      default = null;
      type = nullOr (either package (listOf package));
      description = ''
        A derivation (or list of derivations) copied in the image root directory (store path prefixes /nix/store/hash-path are removed, in order to relocate them at the image /).
      '';
    };

    maxLayers = mkOption {
      type = int;
      default = 1;
      description = ''
        The maximum number of layers to create.
        Note this is applied on the image layers and not on layers added with the 'layers' attribute.
      '';
    };

    perms = mkOption {
      type = listOf attrs;
      default = [ ];
      description = ''
        A list of file permisssions which are set when the tar layer is created: these permissions are not written to the Nix store.
      '';
      example = literalExample ''
        {
          path = "a store path";
          regex = ".*";
          mode = "0664";
        }
      '';
    };

    layers = mkOption {
      type = listOf package;
      default = [ ];
      description = ''
        A list of layers built with the buildLayer function: If a store path in deps or contents belongs to one of these layers, this store path is skipped. This is pretty useful to isolate store paths that are often updated from more stable store paths, to speed up build and push time.
      '';
    };

    reproducible = mkOption {
      type = bool;
      default = true;
      description = ''
        Store the layer tar in the derivation. This is useful when the layer dependencies are not bit reproducible.
      '';
    };

    setup = mkOption {
      default = { };
      description = ''
        OCI image setup scripts to generate more complex layers
      '';
      type = attrsOf (submodule {
        options = {
          local = mkOption {
            type = bool;
            default = true;
            description = ''
              Should this script be executed locally. More often then not these scripts are faster to run localy than to pull the result from the cache
            '';
          };
          script = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              Script to be executed to build a layer
            '';
          };
          drv = mkOption {
            type = nullOr package;
            default = null;
            description = ''
              Derivation used instead of setup script. Takes preferece over `local` and `script` arguments.
            '';
          };
          perms = mkOption {
            default = null;
            description = ''
              Permissions for the generated output
            '';
            type = nullOr (submodule {
              regex = mkOption {
                type = str;
                example = ".*";
                description = ''
                  Path regex for which permisions should be set
                '';
              };
              mode = mkOption {
                type = nullOr str;
                example = "0777";
                description = ''
                  File mode for paths matching the regex
                '';
              };
            });

          };
        };
      });
    };

    directories = mkOption {
      default = { };
      example = literalExpression ''
        {
          "/tmp".mode = "1777";
        }
      '';

      type = with types; attrsOf (submodule (
        { name, config, options, ... }:
        {
          options = {

            enable = mkOption {
              type = bool;
              default = true;
              description = ''
                Whether this file should be generated. This option allows specific files to be disabled.
              '';
            };

            target = mkOption {
              type = types.str;
              description = ''
                Directory name. Defaults to the attribute name.
              '';
            };

            mode = mkOption {
              type = types.str;
              default = "symlink";
              example = "0600";
              description = ''
                If set to something else than `symlink`, the file is copied instead of symlinked, with the given file mode.
              '';
            };

            uid = mkOption {
              default = 0;
              type = types.int;
              description = ''
                UID of created file. Only takes effect when the file is copied (that is, the mode is not 'symlink').
              '';
            };

            gid = mkOption {
              default = 0;
              type = types.int;
              description = ''
                GID of created file. Only takes effect when the file is copied (that is, the mode is not 'symlink').
              '';
            };
          };

          config = {
            target = mkDefault name;
          };

        }
      ));

    };

    files = mkOption {
      default = { };
      example = literalExpression ''
        {
          "etc/example-configuration-file" = {
            source = "/nix/store/.../dir/file.conf.example";
            mode = "0440";
          };
          "etc/default/useradd".text = "GROUP=100 ...";
        }
      '';

      type = with types; attrsOf (submodule (
        { name, config, options, ... }:
        {
          options = {

            enable = mkOption {
              type = bool;
              default = true;
              description = ''
                Whether this file should be generated. This option allows specific files to be disabled.
              '';
            };

            target = mkOption {
              type = types.str;
              description = ''
                Name of symlink. Defaults to the attribute name.
              '';
            };

            text = mkOption {
              default = null;
              type = types.nullOr types.lines;
              description = "Text of the file.";
            };

            source = mkOption {
              type = types.path;
              description = "Path of the source file.";
            };

            mode = mkOption {
              type = types.str;
              default = "symlink";
              example = "0600";
              description = ''
                If set to something else than `symlink`, the file is copied instead of symlinked, with the given file mode.
              '';
            };

            uid = mkOption {
              default = 0;
              type = types.int;
              description = ''
                UID of created file. Only takes effect when the file is copied (that is, the mode is not 'symlink').
              '';
            };

            gid = mkOption {
              default = 0;
              type = types.int;
              description = ''
                GID of created file. Only takes effect when the file is copied (that is, the mode is not 'symlink').
              '';
            };
          };

          config = {
            target = mkDefault name;
            source = mkIf (config.text != null) (
              let name' = "file-" + lib.replaceStrings [ "/" ] [ "-" ] name;
              in mkDerivedConfig options.text (pkgs.writeText name')
            );
          };

        }
      ));

    };
  };

  config =
    let
      files' = filter (f: f.enable) (attrValues config.files);
      directories' = filter (f: f.enable) (attrValues config.directories);
      mkRun = isLocal: if isLocal then pkgs.runCommandLocal else pkgs.runCommand;

      rootEnv = (pkgs.buildEnv {
        name = "setup";
        paths = (mapAttrsToList (n: v: if v.drv != null then v.drv else (mkRun v.local) n { } v.script) config.setup);
      });

      filesSetup = pkgs.runCommandLocal "files-setup" { } ''
        set -euo pipefail

        makeEntry() {
          src="$1"
          target="$2"
          mode="$3"

          if [[ "$src" = *'*'* ]]; then
            # If the source name contains '*', perform globbing.
            mkdir -p "$out/$target"
            for fn in $src; do
                ln -s "$fn" "$out/$target/"
            done
          else

            mkdir -p "$out/$(dirname "$target")"
            if ! [ -e "$out/$target" ]; then
              if [ $mode = "symlink" ]; then
                ln -s "$src" "$out/$target"
              else
                cp "$src" "$out/$target"
              fi
            else
              echo "duplicate entry $target -> $src"
              if [ "$(readlink "$out/$target")" != "$src" ]; then
                echo "mismatched duplicate entry $(readlink "$out/$target") <-> $src"
                ret=1

                continue
              fi
            fi
          fi
        }

        mkdir -p "$out"
        ${concatMapStringsSep "\n" (entry: escapeShellArgs [
          "makeEntry"
          # Force local source paths to be added to the store
          "${entry.source}"
          entry.target
          entry.mode
        ]) files'}

        ${concatMapStringsSep " " (entry: "mkdir -p \"$out/${entry.target}\"") directories'}
      '';
    in
    {

      copyToRoot = lib.mkIf (config.setup != { })
        [
          rootEnv
          filesSetup
        ];

      perms = map
        (value: {
          path = filesSetup;
          regex = if lib.hasPrefix "/" value.target then value.target else "/${value.target}";
          inherit (value) uid gid;
        } // (lib.optionalAttrs (value.mode != "symlink") { inherit (value) mode; }))
        (files' ++ directories');



    };

}
