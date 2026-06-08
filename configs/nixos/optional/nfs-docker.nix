# NFS mounts for Docker hosts running compose-farm services
# NAS: truenas.local
#
# See: https://github.com/basnijholt/compose-farm/blob/main/docs/truenas-nested-nfs.md
#
# - nofail: Don't block boot if NAS is down
# - bg: Retry in background if mount fails at boot
# - wait-online@br0: Don't try TrueNAS before the wired bridge has IPv4,
#   otherwise the request can leave over Wi-Fi and be denied by TrueNAS ACLs.
# - soft: Return errors instead of hanging when NAS unreachable
# - NFSv4 handles reconnection automatically when NAS comes back
{ ... }:

let
  nfsOptions = [
    "nfsvers=4"
    "nofail"
    "bg"
    "soft"
    "timeo=50"
    "_netdev"
    "x-systemd.requires=systemd-networkd-wait-online@br0.service"
    "x-systemd.after=systemd-networkd-wait-online@br0.service"
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
