{
  pkgs,
  lib ? pkgs.lib,
  builder,
}:
let
  ls = "${lib.getExe pkgs.eza} -glahF --octal-permissions --time-style '+ ' --color=always";

  diffLayersJson =
    name: oci:
    pkgs.runCommandLocal "${name}-test" { } ''
      mkdir $out
      cat ${oci} | ${lib.getExe pkgs.jq} > $out/result.json
      diff ${./${name}.json} $out/result.json
    '';

  compareOutput =
    {
      image,
      compareWith,
      test,
    }:
    let
      image' = builder (image // { entrypoint = [ (pkgs.writeShellScript "entrypoint" test) ]; });
    in
    pkgs.runCommandLocal "${image.name}-compare-output-test"
      {
        passthru = {
          image = image';
        };
      }
      ''
        mkdir -p $out
        export PATH=$PATH:${lib.makeBinPath [ pkgs.docker ]}
        ${image'.load}/bin/load
        docker run -h ${image'.name} ${image'.imageRefUnsafe} > $out/result
        sed --regexp-extended 's|/nix/store/(.{36})-|/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-|g' -i $out/result
        cp $out/result result

        diff ${compareWith} $out/result || ret=$?
        if [ $ret -ne 0 ];
        then
          echo -e "\e[33mActual output:\e[0m\n"
          cat $out/result
          echo
          echo -e "\e[31mError: test failed\e[0m\n"
          exit $ret
        else
          echo -e "\n\e[32mTest passed\e[0m"
        fi
      '';
in
{
  empty = diffLayersJson "empty" (builder {
    name = "empty";
  });

  config = diffLayersJson "config" (builder {
    name = "config";
    user = "test";
    exposedPorts = {
      "8080/tcp" = { };
    };
    env.TEST = "abc";
    entrypoint = [ "/bin/whatever" ];
    cmd = [
      "-a"
      "-b"
      "-c"
    ];
    workingDir = "/something";
    labels = {
      testLabel = "test";
    };
    stopSignal = "5";
  });

  usersAndPerms = compareOutput {
    image = {
      name = "users-and-perms";
      packages = with pkgs; [
        bash
        eza
        coreutils
      ];

      users.root = {
        uid = 0;
        gid = 0;
        group = "root";
        withHome = true;
        shell = "/bin/bash";
      };

      users.test2 = {
        uid = 1000;
        gid = 1000;
        group = "test2";
        withHome = true;
      };

      directories."something/abc" = { };
      directories."/tmp".mode = "1777";

      files."something/test1".text = "Hello world";
      files."something/test2" = {
        text = "Hello World";
        mode = "0777";
        uid = 1000;
        gid = 1000;
      };
      files."something/test3" = {
        text = "Hello World";
        mode = "0666";
        uid = 1001;
        gid = 1001;
      };
    };

    test = ''
      echo -e "\nROOT:"
      ${ls} /
      echo -e "\nETC:"
      ${ls} /etc
      echo -e "\nSOMETHING:"
      ${ls} /something
      echo -e "\nHOME:"
      ${ls} /home

      echo -e "\nSHADOW:"
      cat /etc/shadow

      echo -e "\nPASSWD:"
      cat /etc/passwd

      echo -e "\nGROUP:"
      cat /etc/group

      echo -e "\nGSHADOW:"
      cat /etc/gshadow
    '';

    compareWith = ./users-and-perms;
  };
}
