# GitHub repository backup/mirror sync
# Run manually: sudo systemctl start github-backup-sync
# Check logs: journalctl -u github-backup-sync -f
{ pkgs, ... }:

{
  systemd.services.github-backup-sync = {
    description = "Mirror all accessible GitHub repositories";
    path = with pkgs; [ git gh openssh ];
    script = ''
      ${pkgs.uv}/bin/uvx github-backup-sync \
        --root /mnt/tank/backups/github \
        --prune
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "basnijholt";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.github-backup-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1h";
      OnUnitActiveSec = "3d";
      Persistent = true;
    };
  };
}
