#!/usr/bin/env bash
# Pi4 SSD Verify Script (UEFI)
# Verifies bootloader, firmware, and ZFS root for the Pi4 SSD image.

set -euo pipefail

LOG_FILE="/tmp/pi4-verify.log"
DISK_DEV="/dev/sda"

fail() {
  echo "❌ $1" >&2
  exit 1
}

cleanup() {
  sudo umount /mnt/pi4-root 2>/dev/null || true
  sudo umount /mnt/pi4-nix 2>/dev/null || true
  sudo umount /mnt/pi4-boot 2>/dev/null || true
  sudo zpool export zroot 2>/dev/null || true
}
trap cleanup EXIT

# Ensure log is readable by all
rm -f "$LOG_FILE" 2>/dev/null || sudo rm -f "$LOG_FILE" 2>/dev/null || true
exec > >(tee "$LOG_FILE") 2>&1

echo "=========================================="
echo "Pi4 SSD Verify (UEFI) - $(date)"
echo "=========================================="
echo ""

# --- Partition Layout ---
echo "=== PARTITION LAYOUT ==="
lsblk -f "$DISK_DEV" 2>/dev/null || lsblk -f
echo ""

echo "=== Partition metadata check ==="
if ! sudo blkid -o export "${DISK_DEV}1"; then
  fail "Cannot read metadata for ${DISK_DEV}1"
fi
ESP_TYPE=$(sudo blkid -o value -s TYPE "${DISK_DEV}1" 2>/dev/null || true)
if [ "$ESP_TYPE" != "vfat" ]; then
  fail "ESP ${DISK_DEV}1 is not vfat (TYPE=$ESP_TYPE)"
fi
echo "✅ ESP filesystem type is vfat"
echo ""

# --- Mount partitions ---
echo "=== MOUNTING PARTITIONS ==="
sudo mkdir -p /mnt/pi4-boot /mnt/pi4-nix /mnt/pi4-root
if ! sudo mount "${DISK_DEV}1" /mnt/pi4-boot 2>/dev/null; then
  if ! findmnt -rno TARGET /mnt/pi4-boot >/dev/null 2>&1; then
    fail "Failed to mount ESP ${DISK_DEV}1 at /mnt/pi4-boot"
  fi
fi

if ! sudo zpool import -N zroot 2>/dev/null; then
  if ! sudo zpool list -Ho name zroot >/dev/null 2>&1; then
    fail "Failed to import zpool zroot"
  fi
fi

if ! sudo mount -t zfs zroot/nix /mnt/pi4-nix 2>/dev/null; then
  if ! findmnt -rno TARGET /mnt/pi4-nix >/dev/null 2>&1; then
    fail "Failed to mount zroot/nix at /mnt/pi4-nix"
  fi
fi
echo ""

# --- ESP Partition (UEFI + systemd-boot) ---
echo "=========================================="
echo "=== ESP PARTITION (/boot) ==="
echo "=========================================="
echo ""

echo "=== Directory listing ==="
ls -la /mnt/pi4-boot/ 2>&1 || echo "Cannot list"
echo ""

echo "=== UEFI firmware (RPI_EFI.fd) ==="
if [ -f /mnt/pi4-boot/RPI_EFI.fd ]; then
  echo "✅ UEFI firmware present"
  ls -la /mnt/pi4-boot/RPI_EFI.fd
else
  fail "UEFI firmware MISSING"
fi
echo ""

echo "=== config.txt ==="
cat /mnt/pi4-boot/config.txt 2>&1 || fail "config.txt not found"
echo ""

echo "=== systemd-boot installed? ==="
if [ -f /mnt/pi4-boot/EFI/BOOT/BOOTAA64.EFI ]; then
  echo "✅ BOOTAA64.EFI present"
  ls -la /mnt/pi4-boot/EFI/BOOT/BOOTAA64.EFI
else
  fail "BOOTAA64.EFI MISSING"
fi
if [ -d /mnt/pi4-boot/EFI/systemd ]; then
  echo "✅ systemd-boot directory exists"
  ls -la /mnt/pi4-boot/EFI/systemd/
else
  fail "systemd-boot directory MISSING"
fi
echo ""

echo "=== loader.conf ==="
if [ -f /mnt/pi4-boot/loader/loader.conf ]; then
  echo "✅ loader.conf present"
  cat /mnt/pi4-boot/loader/loader.conf
else
  fail "loader.conf MISSING"
fi
echo ""

echo "=== Boot entries ==="
ls -la /mnt/pi4-boot/loader/entries/ 2>&1 || echo "No boot entries"
BOOT_ENTRY="/mnt/pi4-boot/loader/entries/nixos.conf"
if [ -f "$BOOT_ENTRY" ]; then
  echo ""
  echo "=== nixos.conf contents ==="
  cat "$BOOT_ENTRY"
else
  fail "nixos.conf missing from loader entries"
fi
echo ""

echo "=== Validating boot entry targets ==="
LINUX_PATH=$(grep -E '^linux ' "$BOOT_ENTRY" | awk '{print $2}' || true)
INITRD_PATH=$(grep -E '^initrd ' "$BOOT_ENTRY" | awk '{print $2}' || true)
OPTIONS_LINE=$(grep -E '^options ' "$BOOT_ENTRY" || true)

[ -n "$LINUX_PATH" ] || fail "linux path missing in boot entry"
[ -n "$INITRD_PATH" ] || fail "initrd path missing in boot entry"
[ -n "$OPTIONS_LINE" ] || fail "options line missing in boot entry"

if ! printf '%s' "$OPTIONS_LINE" | grep -q 'root=ZFS=zroot/root'; then
  fail "root=ZFS=zroot/root missing from boot options"
fi

SYSTEM_PATH=$(printf '%s' "$OPTIONS_LINE" | sed -n 's/.*init=\([^ ]*\)\/init.*/\1/p')
[ -n "$SYSTEM_PATH" ] || fail "init= path missing from boot options"

if [ ! -s "/mnt/pi4-boot${LINUX_PATH}" ]; then
  fail "Kernel not found at /mnt/pi4-boot${LINUX_PATH}"
fi
if [ ! -s "/mnt/pi4-boot${INITRD_PATH}" ]; then
  fail "Initrd not found at /mnt/pi4-boot${INITRD_PATH}"
fi

# Convert system path into store path under the mounted nix store
SYSTEM_STORE_PATH="/mnt/pi4-nix${SYSTEM_PATH}"
if [[ "$SYSTEM_PATH" == /nix/* ]]; then
  SYSTEM_STORE_PATH="/mnt/pi4-nix${SYSTEM_PATH#/nix}"
fi

if [ ! -d "$SYSTEM_STORE_PATH" ]; then
  fail "System closure missing at $SYSTEM_STORE_PATH"
fi
for f in init kernel initrd; do
  if [ ! -e "$SYSTEM_STORE_PATH/$f" ]; then
    fail "System closure missing $f at $SYSTEM_STORE_PATH/$f"
  fi
done
echo "✅ Boot entry targets exist (kernel, initrd, system closure)"
echo ""

echo "=== NixOS kernels ==="
ls -la /mnt/pi4-boot/EFI/nixos/ 2>&1 | head -20 || echo "No NixOS kernels"
echo ""

# --- ZFS Pool ---
echo "=========================================="
echo "=== ZFS POOL ==="
echo "=========================================="
echo ""

echo "=== Pool status ==="
sudo zpool status zroot 2>&1 || echo "Cannot get pool status"
if ! sudo zpool status -x zroot >/tmp/zpool-health.txt 2>&1; then
  cat /tmp/zpool-health.txt
  fail "zpool zroot is not healthy"
fi
cat /tmp/zpool-health.txt
echo ""

echo "=== Verifying ZFS bootfs ==="
BOOTFS=$(sudo zpool get -H -o value bootfs zroot 2>/dev/null)
if [ "$BOOTFS" = "zroot/root" ]; then
  echo "✅ bootfs correctly set to zroot/root"
else
  fail "bootfs is '$BOOTFS' (expected zroot/root)"
fi
sudo zpool get bootfs zroot
echo ""

echo "=== ZFS datasets ==="
sudo zfs list -r zroot 2>&1 || fail "Cannot list datasets"
if ! sudo zfs list zroot/root >/dev/null 2>&1; then
  fail "Dataset zroot/root missing"
fi
echo ""

echo "=== Mounting zroot/root for sanity checks ==="
if ! sudo mount -t zfs zroot/root /mnt/pi4-root 2>/dev/null; then
  if ! findmnt -rno TARGET /mnt/pi4-root >/dev/null 2>&1; then
    fail "Failed to mount zroot/root at /mnt/pi4-root"
  fi
fi
if [ ! -f /mnt/pi4-root/etc/NIXOS ]; then
  fail "/etc/NIXOS marker missing in root filesystem"
fi
if [ -f /mnt/pi4-root/etc/hostid ]; then
  echo "Hostid on disk: $(cat /mnt/pi4-root/etc/hostid)"
else
  echo "Warning: /etc/hostid not found on root filesystem"
fi
echo ""

# --- Nix Store ---
echo "=========================================="
echo "=== NIX STORE ==="
echo "=========================================="
echo ""

echo "=== Package count ==="
PKGCOUNT=$(ls /mnt/pi4-nix/store/ 2>/dev/null | wc -l)
echo "Packages in store: $PKGCOUNT"
echo ""

echo "=== System closure ==="
ls /mnt/pi4-nix/store/ | grep nixos-system-pi4 | head -3 || echo "No system found"
echo ""

echo "=== Nix profiles ==="
ls -la /mnt/pi4-nix/var/nix/profiles/ 2>/dev/null || echo "No profiles"
echo ""

# --- Cleanup ---
echo "=========================================="
echo "=== CLEANUP ==="
echo "=========================================="
echo "Unmounting and exporting zpool..."
echo "Done."
echo ""

echo "=========================================="
echo "Log saved to: $LOG_FILE"
echo "=========================================="
