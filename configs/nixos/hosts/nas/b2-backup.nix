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
    description = "Start the B2 backup if the docker mirror is mounted";
    restartIfChanged = false;
    unitConfig.OnFailure = [ "nas-health-alert@%n.service" ];
    path = [
      config.boot.zfs.package
      pkgs.gawk
    ];
    script = ''
      set -o pipefail
      # A catch-up run at boot starts before the key arrives; give the
      # mounts up to two hours.
      for _ in $(seq 120); do
        unmounted=$(zfs list -H -o name,canmount,mounted,mountpoint -r tank/backups/ssd/docker |
          awk -F'\t' '$2 == "on" && $3 != "yes" && $4 != "legacy" && $4 != "none" { print $1 }') ||
          unmounted="tank/backups/ssd/docker (zfs list failed)"
        [ -z "$unmounted" ] && break
        sleep 60
      done
      if [ -n "$unmounted" ]; then
        echo "not syncing to B2; not mounted:"
        echo "$unmounted"
        exit 1
      fi
      ${incus} exec docker -- /run/current-system/sw/bin/systemctl start rclone-b2-backup.service
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.timers.nas-b2-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };
}
