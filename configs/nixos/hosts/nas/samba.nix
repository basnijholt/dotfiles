{ pkgs, ... }:

{
  services.samba = {
    enable = true;
    openFirewall = true;
    nmbd.enable = true;
    winbindd.enable = false;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "NAS Server";
        "netbios name" = "NAS";
        "security" = "user";
        "map to guest" = "Bad User";
        "guest account" = "nobody";
        "ea support" = "no";
        "vfs objects" = "catia fruit streams_xattr io_uring";
        "fruit:aapl" = "yes";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
        "fruit:nfs_aces" = "no";
        "fruit:resource" = "stream";
        "fruit:zero_file_id" = "no";
        "spotlight" = "no";
        "smb1 unix extensions" = "no";
        "server min protocol" = "SMB2_02";
      };

      timemachine = {
        path = "/mnt/tank/timemachine";
        browseable = "yes";
        "read only" = "no";
        "valid users" = "basnijholt marcella";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "0";
      };

      photos = {
        path = "/mnt/tank/photos";
        browseable = "yes";
        "read only" = "no";
        "valid users" = "basnijholt marcella";
        "durable handles" = "yes";
        "fruit:encoding" = "native";
      };

      media = {
        path = "/mnt/tank/media";
        browseable = "yes";
        "read only" = "no";
        "valid users" = "basnijholt marcella";
      };

      share = {
        path = "/mnt/tank/share";
        browseable = "yes";
        "guest ok" = "yes";
        "read only" = "no";
        "durable handles" = "yes";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
    workgroup = "WORKGROUP";
    hostname = "NAS";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  systemd.services.nas-smb-permissions = {
    description = "Ensure NAS SMB share root permissions";
    wants = [ "zfs.target" ];
    after = [ "zfs.target" ];
    before = [ "samba-smbd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils ];
    script = ''
      test -d /mnt/tank/timemachine
      chown root:timemachine /mnt/tank/timemachine
      chmod 0770 /mnt/tank/timemachine
    '';
    serviceConfig.Type = "oneshot";
  };
}
