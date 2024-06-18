{ lib, config, ... }:
let
  cfg = config.users;
  inherit (lib) mkOption types;
in
{
  options = {

    users = mkOption {
      default = { };
      description = ''
        User accounts to be created on the image
      '';
      type = types.attrsOf (types.submodule {
        options = {
          uid = mkOption {
            type = types.int;
            description = ''
              Account UID
            '';
          };

          gid = mkOption {
            type = types.int;
            description = ''
              Account GID
            '';
          };

          group = mkOption {
            default = "+${toString config.gid}";
            type = types.str;
            description = ''
              The user’s primary group.
            '';
          };

          shell = mkOption {
            type = types.str;
            default = "";
            description = ''
              Path to users shell
            '';
          };

          withHome = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Should home directory be created
            '';
          };
        };
      });
    };
  };

  config = {

    directories = lib.mapAttrs'
      (n: v: {
        name = if n == "root" then "/root" else "/home/${n}";
        value = {
          mode = "0744";
          inherit (v) uid gid;
        };
      })
      config.users;

    files."etc/passwd" = lib.mkIf (cfg != { }) {
      mode = "0444";
      text = lib.concatMapStringsSep ""
        (userName:
          let
            user = cfg.${userName};
            homeDir =
              if userName == "root"
              then "/root"
              else lib.optionalString user.withHome "/home/${userName}";
          in
          ''
            ${userName}:x:${toString user.uid}:${toString user.gid}::${homeDir}:${user.shell}
          '')
        (lib.attrNames cfg);
    };

    files."etc/shadow" = lib.mkIf (cfg != { }) {
      mode = "0440";
      text = lib.concatMapStringsSep ""
        (userName: ''
          ${userName}:!x:::::::
        '')
        (lib.attrNames cfg);
    };

    files."etc/group" = lib.mkIf (cfg != { }) {
      mode = "0444";
      text = lib.concatMapStringsSep ""
        (userName: ''
          ${cfg.${userName}.group}:x:${toString cfg.${userName}.gid}:
        '')
        (lib.attrNames cfg);
    };

    files."etc/gshadow" = lib.mkIf (cfg != { }) {
      mode = "0440";
      text = lib.concatMapStringsSep ""
        (userName: ''
          ${cfg.${userName}.group}:x::
        '')
        (lib.attrNames cfg);
    };

  };
}
