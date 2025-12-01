# ZFS automated snapshots and replication to TrueNAS
{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    lzop
    mbuffer
    sanoid # Provides syncoid command
  ];

  # --- Automated Local Snapshots ---
  # Keeps a rolling history of snapshots locally for quick recovery
  services.zfs.autoSnapshot = {
    enable = true;
    flags = "-k -p";
    frequent = 6; # Every 10 minutes (6 per hour)
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 12;
  };

  # --- Replication Service (Syncoid) ---
  # Pushes snapshots to TrueNAS via SSH
  #
  # === Setup Instructions ===
  #
  # 1. Create Target Datasets on TrueNAS:
  #    - SSH into TrueNAS or use the Shell in Web UI:
  #      `zfs create tank/backups/<hostname>` (e.g. tank/backups/nuc)
  #
  # 2. Setup SSH Access (Root to Root):
  #    - On this NixOS machine, get the root public key:
  #      `sudo cat /root/.ssh/id_ed25519.pub`
  #      (If file missing: `sudo ssh-keygen -t ed25519`)
  #    - On TrueNAS Web UI:
  #      Go to Credentials -> Local Users -> root -> SSH Public Key
  #      Paste the key and Save.
  #
  # 3. Verify Connection:
  #    - On this NixOS machine:
  #      `sudo ssh root@truenas.local zfs list`
  #      (Accept the host key if prompted)
  systemd.services.zfs-replication = {
    description = "ZFS replication to TrueNAS";
    requires = [ "network-online.target" ];
    after = [ "network-online.target" ];
    
    path = with pkgs; [
      openssh
      sanoid
      lzop
      mbuffer
      gawk
      nettools
    ];

    script = ''
      set -euo pipefail

      TARGET_USER="root"
      TARGET_HOST="truenas.local"
      # Target pool structure: tank/backups/<hostname>/<dataset>
      TARGET_PATH="tank/backups/${config.networking.hostName}"

      # Replicate Home (Most important)
      # recursive=true includes sub-datasets
      syncoid \
        --no-privilege-check \
        --recursive \
        --sshport=22 \
        zroot/home \
        "$TARGET_USER@$TARGET_HOST:$TARGET_PATH/home"

      # Replicate Var (Logs, databases, system state)
      syncoid \
        --no-privilege-check \
        --recursive \
        --sshport=22 \
        zroot/var \
        "$TARGET_USER@$TARGET_HOST:$TARGET_PATH/var"

      # Replicate Root (System config, /root, /etc)
      syncoid \
        --no-privilege-check \
        --recursive \
        --sshport=22 \
        zroot/root \
        "$TARGET_USER@$TARGET_HOST:$TARGET_PATH/root"
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      # Restart on failure to handle temporary network glitches
      Restart = "on-failure";
      RestartSec = "10m";
      # Allow initial replication to take as long as needed
      TimeoutStartSec = "infinity";
    };
  };

  # --- Daily Timer ---
  systemd.timers.zfs-replication = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
