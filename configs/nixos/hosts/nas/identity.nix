# UID/GID mapping copied from the current NAS so existing dataset ownership
# keeps resolving to the same names after migration.
{ lib, pkgs, ... }:

{
  users.groups = {
    basnijholt.gid = 3000;
    docker.gid = lib.mkForce 999;
    marcella.gid = 3001;
    restic.gid = 3003;
    containers-share.gid = 3006;
  };

  users.users = {
    basnijholt = {
      isNormalUser = lib.mkForce false;
      isSystemUser = true;
      uid = 501;
      group = "basnijholt";
      home = "/home/basnijholt";
      createHome = true;
    };

    docker = {
      isSystemUser = true;
      uid = 1000;
      group = "docker";
      home = "/var/empty";
      shell = "${pkgs.shadow}/bin/nologin";
    };

    marcella = {
      isSystemUser = true;
      uid = 3000;
      group = "marcella";
      home = "/var/empty";
      shell = "${pkgs.shadow}/bin/nologin";
    };

    restic = {
      isSystemUser = true;
      uid = 3002;
      group = "restic";
      home = "/mnt/tank/backups";
      shell = pkgs.bashInteractive;
    };
  };
}
