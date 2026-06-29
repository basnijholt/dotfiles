# ZFS replication to the NAS via syncoid
# Imports zfs-auto-snapshot.nix for local snapshots (required for syncoid)
{ config, pkgs, ... }:

{
  imports = [
    ./zfs-auto-snapshot.nix
  ];

  environment.systemPackages = with pkgs; [
    lzop
    mbuffer
    sanoid # Provides syncoid command
  ];

  # --- Replication Service (Syncoid) ---
  # Pushes snapshots to the NAS via SSH
  #
  # === Setup Instructions ===
  #
  # 1. Create Target Datasets on the NAS:
  #    - SSH into the NAS:
  #      `zfs create tank/backups/<hostname>` (e.g. tank/backups/nuc)
  #
  # 2. Setup SSH Access (Root to Root):
  #    - On this NixOS machine, get the root public key:
  #      `sudo cat /root/.ssh/id_ed25519.pub`
  #      (If file missing: `sudo ssh-keygen -t ed25519`)
  #    - On the NAS, add the source root public key to
  #      /etc/ssh/authorized_keys.d/root.
  #      SECURITY TIP: Prepend `from="<NIXOS_IP>"` to the key to restrict usage.
  #      Example: `from="192.168.1.26" ssh-ed25519 ...`
  #      (Save changes)
  #
  # 3. Verify Connection:
  #    - On this NixOS machine:
  #      `sudo ssh root@192.168.1.4 zfs list`
  #      (Accept the host key if prompted)
  systemd.services.zfs-replication = {
    description = "ZFS replication to NAS";
    requires = [ "network-online.target" ];
    after = [ "network-online.target" ];
    
    path = with pkgs; [
      openssh
      sanoid
      lzop
      mbuffer
      gawk
      nettools
      zfs
    ];

    script = ''
      set -euo pipefail

      TARGET_USER="root"
      TARGET_HOST="192.168.1.4"
      # Target pool structure: tank/backups/<hostname>/<dataset>
      TARGET_PATH="tank/backups/${config.networking.hostName}"

      # This is a timer-driven best-effort backup job. If the NAS is not
      # reachable yet, skip this run instead of poisoning system activation.
      if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$TARGET_USER@$TARGET_HOST" true >/dev/null 2>&1; then
        echo "Skipping ZFS replication: $TARGET_HOST is not reachable over SSH"
        exit 0
      fi

      # Replicate Home (Most important)
      # recursive=true includes sub-datasets
      syncoid \
        --recursive \
        --delete-target-snapshots \
        --sshport=22 \
        zroot/home \
        "$TARGET_USER@$TARGET_HOST:$TARGET_PATH/home"

      # Replicate Var (Logs, databases, system state)
      syncoid \
        --recursive \
        --delete-target-snapshots \
        --sshport=22 \
        zroot/var \
        "$TARGET_USER@$TARGET_HOST:$TARGET_PATH/var"

      # Replicate Root (System config, /root, /etc)
      syncoid \
        --recursive \
        --delete-target-snapshots \
        --sshport=22 \
        zroot/root \
        "$TARGET_USER@$TARGET_HOST:$TARGET_PATH/root"

      # Replicate Incus (VMs/Containers) - only if it exists
      if zfs list zroot/incus >/dev/null 2>&1; then
        syncoid \
          --recursive \
          --delete-target-snapshots \
          --sshport=22 \
          zroot/incus \
          "$TARGET_USER@$TARGET_HOST:$TARGET_PATH/incus"
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "root";
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
