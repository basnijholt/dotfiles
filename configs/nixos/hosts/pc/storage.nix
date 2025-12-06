# Storage configuration (ZFS, swap)
{ ... }:

{
  # --- ZFS Maintenance ---
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # --- Swap ---
  swapDevices = [
    {
      device = "/swapfile";
      size = 48 * 1024; # 48GB
    }
  ];
}