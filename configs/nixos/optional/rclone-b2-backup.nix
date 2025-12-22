# Rclone backup to Backblaze B2 with client-side encryption
# Run manually: sudo systemctl start rclone-b2-backup
# Check logs: journalctl -u rclone-b2-backup -f
{ pkgs, ... }:

{
  systemd.services.rclone-b2-backup = {
    description = "Rclone backup to Backblaze B2 (encrypted)";
    path = [ pkgs.rclone ];
    script = ''
      rclone sync /opt/stacks b2-encrypted:/stacks --config /home/basnijholt/.config/rclone/rclone.conf --verbose
      rclone sync /mnt/data b2-encrypted:/data --config /home/basnijholt/.config/rclone/rclone.conf --verbose
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
