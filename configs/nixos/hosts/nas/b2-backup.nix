{ config, pkgs, ... }:

let
  incus = "${config.virtualisation.incus.package}/bin/incus";
in
{
  # The docker instance's rclone sync copies this mirror to B2. A mirror
  # dataset that is not mounted shows up there as an empty or missing
  # directory, and the sync would delete its files from B2. Only the NAS
  # sees every mirror dataset, so it checks them and then starts the sync.
  systemd.services.nas-b2-backup = {
    description = "Start the B2 backup once the docker mirror is mounted";
    path = [
      config.boot.zfs.package
      pkgs.gawk
    ];
    script = ''
      set -o pipefail
      unmounted=$(zfs list -H -o name,canmount,mounted,mountpoint -r tank/backups/ssd/docker |
        awk -F'\t' '$2 == "on" && $3 != "yes" && $4 != "legacy" && $4 != "none" { print $1 }')
      if [ -n "$unmounted" ]; then
        echo "not syncing to B2; not mounted:"
        echo "$unmounted"
        exit 1
      fi
      ${incus} exec docker -- /run/current-system/sw/bin/systemctl start rclone-b2-backup.service
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-b2-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };
}
