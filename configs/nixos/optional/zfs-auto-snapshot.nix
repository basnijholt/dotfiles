# ZFS automated local snapshots
# Keeps a rolling history of snapshots for quick recovery
{ pkgs, ... }:

{
  # Exclude incus datasets from auto-snapshots (Incus manages its own)
  system.activationScripts.zfsIncusSnapshot.text = ''
    if ${pkgs.zfs}/bin/zfs list zroot/incus &>/dev/null; then
      ${pkgs.zfs}/bin/zfs set com.sun:auto-snapshot=false zroot/incus
    fi
  '';

  services.zfs.autoSnapshot = {
    enable = true;
    flags = "-k -p";
    frequent = 6; # Every 10 minutes (6 per hour)
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 12;
  };
}
