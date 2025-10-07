{ ... }:

{
  # ===================================
  # Hardware Configuration
  # ===================================

  services.fstrim.enable = true;

  # --- Snapper Btrfs Policies ---
  services.snapper.configs = {
    root = {
      SUBVOLUME = "/";
      ALLOW_USERS = [ "basnijholt" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 6;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 6;
      TIMELINE_LIMIT_YEARLY = 2;
      NUMBER_CLEANUP = true;
      NUMBER_MIN_AGE = 1800;
      NUMBER_LIMIT = 10;
    };
    home = {
      SUBVOLUME = "/home";
      ALLOW_USERS = [ "basnijholt" ];
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 6;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 2;
      TIMELINE_LIMIT_MONTHLY = 0;
      TIMELINE_LIMIT_YEARLY = 0;
      NUMBER_CLEANUP = true;
      NUMBER_MIN_AGE = 1800;
      NUMBER_LIMIT = 20;
    };
  };

  # Snapper snapshot roots must exist with correct permissions
  systemd.tmpfiles.rules = [
    "d /.snapshots 0755 root root -"
    "d /home/.snapshots 0755 basnijholt users -"
  ];

  # --- Swap ---
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];
}
