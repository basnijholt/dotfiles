# NFS mounts for Docker hosts running compose-farm services
# NAS: truenas.local
#
# Uses systemd automount for resilience:
# - Mounts on-demand (noauto + x-systemd.automount)
# - Unmounts after 10 min idle (x-systemd.idle-timeout)
# - Fails gracefully instead of hanging (soft + timeo + retrans)
# - Short timeouts prevent system lockups if NAS is down
{ ... }:

let
  nfsOptions = [
    "x-systemd.automount"
    "noauto"
    "x-systemd.idle-timeout=600"
    "x-systemd.device-timeout=5s"
    "x-systemd.mount-timeout=5s"
    "soft"
    "timeo=30"
    "retrans=2"
    "_netdev"
  ];
in
{
  fileSystems."/opt/stacks" = {
    device = "truenas.local:/mnt/ssd/docker/stacks";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/data" = {
    device = "truenas.local:/mnt/ssd/docker/data";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/media" = {
    device = "truenas.local:/mnt/tank/media";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/youtube" = {
    device = "truenas.local:/mnt/tank/youtube";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/photos-export" = {
    device = "truenas.local:/mnt/tank/photos-export";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/syncthing" = {
    device = "truenas.local:/mnt/tank/syncthing";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/frigate" = {
    device = "truenas.local:/mnt/tank/frigate";
    fsType = "nfs";
    options = nfsOptions;
  };
}
