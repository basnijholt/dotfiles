{ pkgs, ... }:

let
  replicationPath = with pkgs; [
    coreutils
    gawk
    gnugrep
    lzop
    mbuffer
    openssh
    sanoid
    zfs
  ];

  syncoidCommon = [
    "--recursive"
    "--compress=lz4"
    "--no-sync-snap"
  ];

  mkSyncoidArgs = pkgs.lib.escapeShellArgs syncoidCommon;
in
{
  environment.systemPackages = with pkgs; [
    sanoid
    lzop
    mbuffer
  ];

  # Existing NixOS hosts push Syncoid backups as root. Keep the shared default
  # root-login denial, but allow key-only root SSH from the LAN for replication.
  # Install source host keys at cutover in /etc/ssh/authorized_keys.d/root with
  # from= restrictions; do not commit those keys to the public repo.
  services.openssh.extraConfig = ''
    Match User root Address 192.168.1.0/24
      PermitRootLogin prohibit-password
  '';

  systemd.services.nas-replicate-ssd-local = {
    description = "Replicate local ssd pool into tank backup dataset";
    wants = [ "zfs.target" ];
    after = [ "zfs.target" ];
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list ssd >/dev/null
      zfs list tank/backups/ssd >/dev/null

      syncoid ${mkSyncoidArgs} ssd tank/backups/ssd
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-ssd-local = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.nas-replicate-ssd-to-nuc = {
    description = "Replicate ssd pool to NUC over SSH";
    wants = [
      "network-online.target"
      "zfs.target"
    ];
    after = [
      "network-online.target"
      "zfs.target"
    ];
    unitConfig.ConditionPathExists = "/etc/ssh/nas-replication-nuc-ed25519";
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list ssd >/dev/null

      syncoid ${mkSyncoidArgs} \
        --sshkey=/etc/ssh/nas-replication-nuc-ed25519 \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        ssd root@192.168.1.2:zroot/backups
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-ssd-to-nuc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:35:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  systemd.services.nas-replicate-hetzner-websites = {
    description = "Pull Hetzner website backups over SSH";
    wants = [
      "network-online.target"
      "zfs.target"
    ];
    after = [
      "network-online.target"
      "zfs.target"
    ];
    unitConfig.ConditionPathExists = "/etc/ssh/nas-replication-hetzner-ed25519";
    path = replicationPath;
    script = ''
      set -euo pipefail

      zfs list tank/backups/hetzner >/dev/null

      syncoid ${mkSyncoidArgs} \
        --include-snaps='^zfs-auto-snap_hourly-' \
        --sshkey=/etc/ssh/nas-replication-hetzner-ed25519 \
        --sshport=22 \
        --sshoption=BatchMode=yes \
        --sshoption=ConnectTimeout=10 \
        root@46.224.10.245:zroot/websites tank/backups/hetzner
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "infinity";
    };
  };

  systemd.timers.nas-replicate-hetzner-websites = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:45:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
