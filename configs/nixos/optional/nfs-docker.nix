# NFS mounts for Docker hosts running compose-farm services
# NAS: nas.local
#
# See: https://github.com/basnijholt/compose-farm/blob/main/docs/truenas-nested-nfs.md
#
# - nofail: Don't block boot if NAS is down
# - bg: Retry in background if mount fails at boot
# - wait-online@br0: Don't try nas before the wired bridge has IPv4,
#   otherwise the request can leave over Wi-Fi and be denied by the NFS export ACLs.
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
    device = "nas.local:/mnt/ssd/docker/stacks";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/data" = {
    device = "nas.local:/mnt/ssd/docker/data";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/media" = {
    device = "nas.local:/mnt/tank/media";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/youtube" = {
    device = "nas.local:/mnt/tank/youtube";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/photos-export" = {
    device = "nas.local:/mnt/tank/photos-export";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/syncthing" = {
    device = "nas.local:/mnt/tank/syncthing";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/frigate" = {
    device = "nas.local:/mnt/tank/frigate";
    fsType = "nfs";
    options = nfsOptions;
  };
}
