# Daily backup of TrueNAS system configuration via REST API
# API key stored in /root/.truenas-api-key
{ pkgs, ... }:

{
  systemd.services.truenas-config-backup = {
    description = "Backup TrueNAS configuration";
    after = [ "network-online.target" ];
    path = with pkgs; [ curl coreutils ];
    script = ''
      BACKUP_DIR="/home/basnijholt/truenas-config-backups"
      mkdir -p "$BACKUP_DIR"
      curl -sf -X POST "http://truenas.local/api/v2.0/config/save" \
        -H "Authorization: Bearer $(cat /root/.truenas-api-key)" \
        -H "Content-Type: application/json" \
        -d '{}' \
        -o "$BACKUP_DIR/truenas-config-$(date +%Y-%m-%d).db"
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.timers.truenas-config-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
