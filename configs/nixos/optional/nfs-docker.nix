# NFS mounts for Docker hosts running compose-farm services
# NAS: truenas.local
{ ... }:

{
  fileSystems."/opt/stacks" = {
    device = "truenas.local:/mnt/docker/stacks";
    fsType = "nfs";
  };

  fileSystems."/mnt/data" = {
    device = "truenas.local:/mnt/docker/data";
    fsType = "nfs";
  };

  fileSystems."/mnt/tank/media" = {
    device = "truenas.local:/mnt/tank/media";
    fsType = "nfs";
  };

  fileSystems."/mnt/tank/youtube" = {
    device = "truenas.local:/mnt/tank/youtube";
    fsType = "nfs";
  };

  fileSystems."/mnt/tank/photos-export" = {
    device = "truenas.local:/mnt/tank/photos-export";
    fsType = "nfs";
  };

  fileSystems."/mnt/tank/syncthing" = {
    device = "truenas.local:/mnt/tank/syncthing";
    fsType = "nfs";
  };

  fileSystems."/mnt/tank/frigate" = {
    device = "truenas.local:/mnt/tank/frigate";
    fsType = "nfs";
  };
}
