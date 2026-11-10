# Rclone backup to Backblaze B2 with client-side encryption
# Run manually: sudo systemctl start rclone-b2-backup
# Check logs: journalctl -u rclone-b2-backup -f
{ pkgs, ... }:

{
  systemd.services.rclone-b2-backup = {
    description = "Rclone backup to Backblaze B2 (encrypted)";
    unitConfig.ConditionPathExists = "/home/basnijholt/.config/rclone/rclone.conf";
    path = [
      pkgs.gawk
      pkgs.rclone
      pkgs.util-linux
    ];
    script = ''
      # A mirror dataset that is not mounted (it failed to mount after the
      # NAS rebooted, or is still being mounted) is an empty directory, and
      # rclone sync would delete its files from B2. Every dataset mounted live
      # must therefore also be mounted in the mirror, once it has been copied.
      for pair in /mnt/data:/mnt/tank/backups/ssd/docker/data /opt/stacks:/mnt/tank/backups/ssd/docker/stacks; do
        live=''${pair%%:*}
        mirror=''${pair#*:}
        for mnt in $(awk -v root="$live" '$5 == root || index($5, root "/") == 1 { print $5 }' /proc/self/mountinfo); do
          copy=$mirror''${mnt#"$live"}
          if [ -e "$copy" ] && ! mountpoint -q "$copy"; then
            echo "$copy is not mounted; not syncing to B2" >&2
            exit 1
          fi
        done
      done

      # Intentionally sync from the NAS backup mirror, not the live mounts
      # (/opt/stacks and /mnt/data). The live Docker trees change while rclone
      # scans/uploads them; the replicated mirror is the stable source for B2.
      rclone sync /mnt/tank/backups/ssd/docker/stacks b2-encrypted:/stacks \
        --config /home/basnijholt/.config/rclone/rclone.conf \
        --verbose \
        --stats 1m \
        --stats-one-line \
        --transfers 4 \
        --fast-list

      rclone sync /mnt/tank/backups/ssd/docker/data b2-encrypted:/data \
        --config /home/basnijholt/.config/rclone/rclone.conf \
        --verbose \
        --stats 1m \
        --stats-one-line \
        --transfers 4 \
        --fast-list
    '';
    postStart = ''
      ${pkgs.coreutils}/bin/date +%s > /var/lib/rclone-b2-backup/last-success-epoch
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "infinity";
      StateDirectory = "rclone-b2-backup";
    };
  };

  systemd.timers.rclone-b2-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };
}
