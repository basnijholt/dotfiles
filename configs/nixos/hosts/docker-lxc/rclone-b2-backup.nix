# Rclone backup to Backblaze B2 with client-side encryption
# Run manually: sudo systemctl start rclone-b2-backup
# Check logs: journalctl -u rclone-b2-backup -f
{ pkgs, ... }:

{
  systemd.services.rclone-b2-backup = {
    description = "Rclone backup to Backblaze B2 (encrypted)";
    path = [ pkgs.rclone ];
    script = ''
      rclone sync /opt/stacks b2-encrypted:/stacks \
        --config /home/basnijholt/.config/rclone/rclone.conf \
        --verbose \
        --stats 1m \
        --stats-one-line \
        --transfers 4 \
        --fast-list \
        --exclude '.venv/**' \
        --exclude 'node_modules/**' \
        --exclude '__pycache__/**'

      rclone sync /mnt/data b2-encrypted:/data \
        --config /home/basnijholt/.config/rclone/rclone.conf \
        --verbose \
        --stats 1m \
        --stats-one-line \
        --transfers 4 \
        --fast-list
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.rclone-b2-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
