# Rclone backup to Backblaze B2 with client-side encryption
# The NAS starts it nightly (nas-b2-backup.timer) once the mirror it reads
# is fully mounted. A manual start skips that check:
#   sudo systemctl start rclone-b2-backup
# Check logs: journalctl -u rclone-b2-backup -f
{ pkgs, ... }:

{
  systemd.services.rclone-b2-backup = {
    description = "Rclone backup to Backblaze B2 (encrypted)";
    unitConfig.ConditionPathExists = "/home/basnijholt/.config/rclone/rclone.conf";
    path = [ pkgs.rclone ];
    script = ''
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
}
