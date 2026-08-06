# UID/GID mapping copied from the current NAS.  The primary user deliberately
# uses UID 1000 and the standard users group (GID 100), matching other hosts
# and the Docker LXC.
{ lib, pkgs, ... }:

{
  users.groups = {
    docker.gid = lib.mkForce 999;
    marcella.gid = 3001;
    restic.gid = 3003;
    timemachine.gid = 3004;
    containers-share.gid = 3006;
  };

  users.users = {
    basnijholt = {
      uid = 1000;
      group = "users";
      extraGroups = [ "timemachine" ];
      home = "/home/basnijholt";
      createHome = true;
    };

    marcella = {
      isSystemUser = true;
      uid = 3000;
      group = "marcella";
      extraGroups = [ "timemachine" ];
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
