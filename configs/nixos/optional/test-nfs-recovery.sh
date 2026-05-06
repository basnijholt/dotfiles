#!/usr/bin/env bash
# Test script for NFS recovery logic
# Run this manually to verify the detection works before relying on the systemd service
#
# Usage:
#   ./test-nfs-recovery.sh          # Check all mounts (dry-run)
#   ./test-nfs-recovery.sh --fix    # Actually fix stale mounts (requires root)

set -uo pipefail

DRY_RUN=true
[[ "${1:-}" == "--fix" ]] && DRY_RUN=false

# NFS mount points to check
NFS_MOUNTS=(
    "/opt/stacks"
    "/mnt/data"
    "/mnt/tank/media"
    "/mnt/tank/youtube"
    "/mnt/tank/photos-export"
    "/mnt/tank/syncthing"
    "/mnt/tank/frigate"
)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

STALE_MOUNTS=()

log_ok() { echo -e "${GREEN}OK${NC}: $1"; }
log_stale() { echo -e "${RED}STALE${NC}: $1"; }
log_skip() { echo -e "${YELLOW}SKIP${NC}: $1"; }
log_info() { echo -e "${YELLOW}INFO${NC}: $1"; }

check_mount() {
    local mount="$1"

    # Skip if mount point doesn't exist
    if [[ ! -d "$mount" ]]; then
        log_skip "$mount (directory doesn't exist)"
        return 0
    fi

    # Check if it's an NFS mount
    if ! findmnt -t nfs,nfs4 "$mount" >/dev/null 2>&1; then
        log_skip "$mount (not an NFS mount)"
        return 0
    fi

    # Show mount details
    local device
    device=$(findmnt -t nfs,nfs4 -n -o SOURCE "$mount" 2>/dev/null || echo "unknown")

    # Use timeout to detect stale/hung mounts
    echo -n "Checking $mount ($device)... "
    if timeout 3 ls "$mount" >/dev/null 2>&1; then
        log_ok "$mount"
        return 0
    else
        log_stale "$mount"
        STALE_MOUNTS+=("$mount")
        return 1
    fi
}

remount_stale() {
    local mount="$1"

    if $DRY_RUN; then
        log_info "Would remount: $mount (dry-run)"
        return
    fi

    log_info "Remounting $mount"
    umount -l "$mount" 2>/dev/null || true
    sleep 1
    mount "$mount" 2>/dev/null || mount -a

    # Verify
    if timeout 3 ls "$mount" >/dev/null 2>&1; then
        log_ok "Recovered: $mount"
    else
        log_stale "FAILED to recover: $mount"
    fi
}

echo "=== NFS Recovery Test ==="
echo "Mode: $($DRY_RUN && echo 'DRY-RUN (use --fix to actually remount)' || echo 'FIX MODE')"
echo ""

for mount in "${NFS_MOUNTS[@]}"; do
    check_mount "$mount" || true
done

echo ""
echo "=== Summary ==="
echo "Checked: ${#NFS_MOUNTS[@]} mount points"
echo "Stale:   ${#STALE_MOUNTS[@]}"

if [[ ${#STALE_MOUNTS[@]} -gt 0 ]]; then
    echo ""
    echo "=== Stale Mounts ==="
    for mount in "${STALE_MOUNTS[@]}"; do
        remount_stale "$mount"
    done

    if ! $DRY_RUN; then
        echo ""
        log_info "Containers need restart to pick up fresh mounts."
        log_info "Run: cf restart (or docker restart \$(docker ps -q))"
    fi
fi
