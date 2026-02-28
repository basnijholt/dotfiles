# NFS mounts for Docker hosts running compose-farm services
# NAS: truenas.local
#
# See: https://github.com/basnijholt/compose-farm/blob/main/docs/truenas-nested-nfs.md
#
# ## Mount Options
#
# - nfsvers=4: NFSv4 protocol (stateful, supports lease recovery)
# - nofail: Don't block boot if NAS is down
# - bg: Retry mounting in background if it fails at boot
# - soft: Return errors instead of hanging indefinitely when NAS unreachable
# - timeo=50: 5 second timeout between retries (50 = 5.0 seconds)
# - _netdev: Wait for network before mounting
#
# ## Why We Need the Recovery Service
#
# Problem: After extended NAS downtime (e.g., 12-hour maintenance), NFS mounts
# become "stale" even after the NAS comes back online. This happens because:
#
# 1. NFSv4 uses stateful leases - when the NAS reboots, it forgets all client state
# 2. Clients hold stale file handles that the server no longer recognizes
# 3. The `soft` mount option returns errors instead of hanging, but doesn't auto-remount
# 4. Docker containers have their own mount namespace - even if the HOST remounts
#    NFS successfully, containers still see the stale mount until restarted
#
# The nfs-recovery service:
# 1. Runs every 5 minutes via systemd timer
# 2. Checks each NFS mount with `timeout 3 ls` to detect stale/hung mounts
# 3. If stale: lazy unmount + remount
# 4. Restarts Docker containers so they pick up the fresh mount namespace
#
# ## Testing
#
# Test script: ./test-nfs-recovery.sh (in this directory)
# Manual trigger: sudo systemctl start nfs-recovery.service
# View logs: journalctl -t nfs-recovery
#
# ## References
#
# - https://engineerworkshop.com/blog/automatically-resolve-nfs-stale-file-handle-errors-in-ubuntu-linux/
# - https://damjan.cvetko.org/blog/2020-05-22-docker-nfs-stale-file-handle/
# - https://access.redhat.com/solutions/2674 (Red Hat: What causes stale NFS file handles)
#
{ config, lib, pkgs, ... }:

let
  nfsOptions = [
    "nfsvers=4"
    "nofail"
    "bg"
    "soft"
    "timeo=50"
    "_netdev"
  ];

  # NFS mount points to monitor - must match fileSystems below
  nfsMountPoints = [
    "/opt/stacks"
    "/mnt/data"
    "/mnt/tank/media"
    "/mnt/tank/youtube"
    "/mnt/tank/photos-export"
    "/mnt/tank/syncthing"
    "/mnt/tank/frigate"
  ];

  nfsRecoveryScript = pkgs.writeShellScript "nfs-recovery" ''
    # NFS Stale Mount Recovery Script
    #
    # Why this exists:
    # After NAS downtime, NFS mounts become stale. The mount point exists but
    # accessing it hangs or returns errors. Docker containers are especially
    # affected because they cache the mount in their namespace.
    #
    # What it does:
    # 1. Check each NFS mount with timeout (detects hung/stale mounts)
    # 2. Lazy unmount stale mounts (umount -l won't block)
    # 3. Remount from fstab
    # 4. Restart containers to pick up fresh mount namespace

    set -uo pipefail

    PATH="${lib.makeBinPath [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.gnugrep
      pkgs.docker
    ]}:$PATH"

    LOG_TAG="nfs-recovery"
    STALE_MOUNTS=()

    log() {
      echo "$1"
      logger -t "$LOG_TAG" "$1" 2>/dev/null || true
    }

    check_mount() {
      local mount="$1"

      # Skip if mount point directory doesn't exist
      if [[ ! -d "$mount" ]]; then
        return 0
      fi

      # Skip if not currently an NFS mount (might not be mounted yet)
      if ! findmnt -t nfs,nfs4 "$mount" >/dev/null 2>&1; then
        return 0
      fi

      # Key check: use timeout to detect stale/hung mounts
      # Exit code 124 = timeout (mount is hung/stale)
      # Any other failure = also treat as stale
      if ! timeout 3 ls "$mount" >/dev/null 2>&1; then
        log "STALE: $mount"
        STALE_MOUNTS+=("$mount")
        return 1
      fi

      return 0
    }

    remount_stale() {
      local mount="$1"
      log "Remounting $mount"

      # Lazy unmount - won't block even if processes have files open
      # The mount will disappear once all file handles are closed
      umount -l "$mount" 2>/dev/null || true

      # Brief pause for unmount to process
      sleep 1

      # Remount - try specific mount first, fall back to mount -a
      if ! mount "$mount" 2>/dev/null; then
        mount -a 2>/dev/null || true
      fi
    }

    restart_containers() {
      log "Restarting Docker containers to pick up fresh NFS mounts"

      # Why restart containers?
      # Docker containers have their own mount namespace. Even after the host
      # remounts NFS, containers still see the old (stale) mount. Restarting
      # gives them a fresh namespace with the working mount.

      # Just restart all LOCAL containers directly
      # (cf restart --all would SSH to other hosts which we don't want)
      local containers
      containers=$(docker ps -q 2>/dev/null || true)
      if [[ -n "$containers" ]]; then
        log "Restarting $(echo "$containers" | wc -l) containers..."
        # shellcheck disable=SC2086
        docker restart $containers 2>/dev/null || true
      else
        log "No running containers to restart"
      fi
    }

    # Main execution
    log "Checking NFS mounts on $(hostname)..."

    for mount in ${lib.concatStringsSep " " (map (m: ''"${m}"'') nfsMountPoints)}; do
      check_mount "$mount" || true
    done

    if [[ ''${#STALE_MOUNTS[@]} -gt 0 ]]; then
      log "Found ''${#STALE_MOUNTS[@]} stale mount(s), recovering..."

      for mount in "''${STALE_MOUNTS[@]}"; do
        remount_stale "$mount"
      done

      # Wait for mounts to stabilize
      sleep 2

      # Verify recovery worked
      RECOVERY_FAILED=0
      for mount in "''${STALE_MOUNTS[@]}"; do
        if ! timeout 3 ls "$mount" >/dev/null 2>&1; then
          log "FAILED to recover: $mount (NAS may still be down)"
          RECOVERY_FAILED=1
        else
          log "Recovered: $mount"
        fi
      done

      # Only restart containers if at least some mounts recovered
      if [[ $RECOVERY_FAILED -eq 0 ]]; then
        restart_containers
        log "Recovery complete"
      else
        log "Some mounts still stale - skipping container restart"
      fi
    else
      # Don't log on every successful check to avoid log spam
      # Uncomment for debugging:
      # log "All NFS mounts healthy"
      :
    fi
  '';
in
{
  # ============================================================================
  # NFS Mount Definitions
  # ============================================================================

  fileSystems."/opt/stacks" = {
    device = "truenas.local:/mnt/ssd/docker/stacks";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/data" = {
    device = "truenas.local:/mnt/ssd/docker/data";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/media" = {
    device = "truenas.local:/mnt/tank/media";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/youtube" = {
    device = "truenas.local:/mnt/tank/youtube";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/photos-export" = {
    device = "truenas.local:/mnt/tank/photos-export";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/syncthing" = {
    device = "truenas.local:/mnt/tank/syncthing";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/tank/frigate" = {
    device = "truenas.local:/mnt/tank/frigate";
    fsType = "nfs";
    options = nfsOptions;
  };

  # ============================================================================
  # NFS Recovery Service
  # ============================================================================
  #
  # Automatically detects and recovers stale NFS mounts after NAS downtime.
  # See header comments for detailed explanation of why this is needed.

  systemd.services.nfs-recovery = {
    description = "Detect and recover stale NFS mounts after NAS downtime";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];

    # Needed for Docker CLI
    path = [ pkgs.docker ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = nfsRecoveryScript;

      # Must run as root for umount/mount operations
      User = "root";

      # Don't mark service as failed if script exits non-zero
      # (e.g., when NAS is still down and recovery fails)
      SuccessExitStatus = "0 1";

      # Note: Cannot use ProtectSystem=strict because we need to umount/mount
      # Cannot use PrivateMounts=true because we need to affect the real mounts
      PrivateTmp = true;
    };
  };

  systemd.timers.nfs-recovery = {
    description = "Run NFS stale mount recovery every 5 minutes";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      # First check 2 minutes after boot (gives NFS time to mount normally)
      OnBootSec = "2min";

      # Then check every 5 minutes
      OnUnitActiveSec = "5min";

      # Randomize start time slightly to avoid thundering herd if multiple hosts
      RandomizedDelaySec = "30s";

      Unit = "nfs-recovery.service";
    };
  };
}
