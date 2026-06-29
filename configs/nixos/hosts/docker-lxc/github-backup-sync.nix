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
      # gh's interactive stored auth did not survive the TrueNAS -> NixOS move
      # (no token on `docker`, expired token on `nixos`). Provide a token
      # reproducibly via an off-repo env file (`GH_TOKEN=...`), same pattern as
      # nas-health-alert.env. The leading "-" makes the file optional, so the
      # unit still builds/runs where the token is not needed.
      EnvironmentFile = "-/etc/github-backup-sync.env";
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
