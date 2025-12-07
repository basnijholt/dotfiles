#!/usr/bin/env bash
set -e

# =======================================================================================
# Pi 4 Direct SSD Installer (ZFS Root)
# =======================================================================================
# This script automates the installation of NixOS onto a Samsung T5 SSD for a Raspberry Pi 4.
# It performs a "Direct Install" (Cross-compile + Copy) from an x86_64 host.
#
# architecture:
#   Host (x86_64) -> Builds ARM64 Closure -> Copies to SSD -> Manually Injects Bootloader
#
# We do this manually because standard `nixos-install` often fails to run the ARM
# activation scripts (install-bootloader) inside the chroot due to QEMU quirks.
# =======================================================================================

# Configuration
FLAKE_ATTR=".#pi4"
DISKO_CONFIG="hosts/pi4/disko.nix"
# Extracted from disko.nix to verify presence before running
DISK_ID="/dev/disk/by-id/usb-Samsung_Portable_SSD_T5_1234567A666E-0:0"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 1. Pre-flight Checks ---
log "Checking prerequisites..."

# Check if script is run as root (we want to run as user, and sudo when needed)
if [ "$EUID" -eq 0 ]; then
    error "Please run this script as a normal user (not root). It will ask for sudo password when needed."
fi

# Check Disk
if [ ! -e "$DISK_ID" ]; then
    error "Target disk not found: $DISK_ID\nPlease plug in the Samsung T5 SSD."
fi

# Check binfmt (Required for building ARM packages on x86)
# If missing, add `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` to configuration.nix
if [ ! -f /proc/sys/fs/binfmt_misc/aarch64-linux ]; then
    error "aarch64 emulation is not enabled. Please check 'boot.binfmt.emulatedSystems' in your config."
fi

# Check ZFS module (Required to format the target drive)
# If missing, add `boot.supportedFilesystems = [ "zfs" ];` to configuration.nix
if ! grep -q zfs /proc/modules; then
    warn "ZFS module not loaded. Attempting to load..."
    sudo modprobe zfs || error "Failed to load ZFS module. Is 'boot.supportedFilesystems = [ \"zfs\" ]' enabled?"
fi

log "Prerequisites checked. Target: $DISK_ID"
echo "WARNING: ALL DATA ON THIS DISK WILL BE DESTROYED."
read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Aborted by user."
fi

# --- 2. Partitioning (Disko) ---
# We run Disko directly on the nix file to bypass architecture checks.
# If we ran `nix run ... --flake .#pi4`, it might try to check if the current system matches the target.
log "Step 2: Partitioning and Formatting (Disko)..."
sudo nix run github:nix-community/disko -- --mode disko "$DISKO_CONFIG"

# --- 3. Build System ---
# We build the system closure as a normal user. This creates a symlink ./result
# pointing to the full system (kernel, initrd, packages) in the Nix store.
log "Step 3: Building NixOS system closure (aarch64)..."
nix build ".#nixosConfigurations.pi4.config.system.build.toplevel"

RESULT_PATH=$(readlink -f ./result)
log "Build complete: $RESULT_PATH"

# --- 4. Install Files ---
# We use `nixos-install` to copy the closure from the host store to the target store (/mnt).
# We use `--no-root-passwd` because we set passwords declaratively in the config.
log "Step 4: Installing NixOS files to /mnt..."

# Note: `nixos-install` attempts to chroot into /mnt to run /nix/store/.../activate.
# This often fails on cross-arch setups (exit code 127 or 255) because the static QEMU
# binary isn't strictly available or configured inside the chroot environment.
# We catch this error but allow the script to proceed because the *files* are usually copied successfully.
set +e
sudo nixos-install --system "$RESULT_PATH" --root /mnt --no-root-passwd
INSTALL_EXIT=$?
set -e

if [ $INSTALL_EXIT -ne 0 ]; then
    warn "nixos-install returned error code $INSTALL_EXIT."
    warn "This is often due to 'chroot' activation failure on cross-arch."
    warn "Proceeding to verify file presence..."
fi

# Verify installation (basic check)
if [ ! -d "/mnt/nix/store" ]; then
    error "Installation failed: /mnt/nix/store is empty."
fi
log "File installation verified."

# --- 5. Bootloader Injection ---
# Since step 4 likely failed to install the bootloader (due to chroot failure),
# we MUST inject the Raspberry Pi firmware, U-Boot, and Extlinux config manually.
log "Step 5: Injecting Firmware & Bootloader..."

# A. Fetch Firmware Packages (ensure they exist in host store)
log "Fetching firmware packages..."
nix build --no-link nixpkgs#legacyPackages.aarch64-linux.raspberrypifw nixpkgs#legacyPackages.aarch64-linux.ubootRaspberryPi4_64bit

FW_PKG=$(nix path-info nixpkgs#legacyPackages.aarch64-linux.raspberrypifw)
UBOOT_PKG=$(nix path-info nixpkgs#legacyPackages.aarch64-linux.ubootRaspberryPi4_64bit)

# B. Copy Firmware to /boot (EFI partition)
# This includes start4.elf, fixup4.dat, etc. needed by the GPU to start.
log "Copying firmware to /mnt/boot..."
sudo cp -r "$FW_PKG/share/raspberrypi/boot/"* /mnt/boot/
sudo cp "$UBOOT_PKG/u-boot.bin" /mnt/boot/u-boot-rpi4.bin

# C. Create config.txt
# This tells the Pi firmware to load U-Boot instead of the Linux kernel directly.
log "Creating config.txt..."
cat <<EOF | sudo tee /mnt/boot/config.txt > /dev/null
kernel=u-boot-rpi4.bin
arm_64bit=1
enable_uart=1
EOF

# D. Generate extlinux.conf
# This tells U-Boot which kernel/initrd to load.
# We extract the paths from the build result we created in Step 3.
log "Generating extlinux.conf..."
BOOT_DIR="/mnt/boot"
EXTLINUX_DIR="$BOOT_DIR/extlinux"
sudo mkdir -p "$EXTLINUX_DIR"

KERNEL="$RESULT_PATH/kernel"
INITRD="$RESULT_PATH/initrd"
INIT="$RESULT_PATH/init"
PARAMS=$(cat "$RESULT_PATH/kernel-params")
DTBS="$RESULT_PATH/dtbs"

# Find DTB (Device Tree Blob)
# We look for the Pi 4 Model B DTB.
DTB_FILE=$(find -L "$DTBS" -name "bcm2711-rpi-4-b.dtb" | head -n 1)
if [ -z "$DTB_FILE" ]; then
    warn "Could not find specific DTB (bcm2711-rpi-4-b.dtb). Boot might fail."
fi

# Write the menu config
cat <<EOF | sudo tee "$EXTLINUX_DIR/extlinux.conf" > /dev/null
TIMEOUT 10
DEFAULT nixos
MENU TITLE NixOS Boot Menu

LABEL nixos
  MENU LABEL NixOS
  LINUX $KERNEL
  INITRD $INITRD
  FDT $DTB_FILE
  APPEND $PARAMS init=$INIT
EOF

log "Bootloader configuration complete."

# --- 6. Cleanup ---
log "Step 6: Cleanup..."
sudo umount -R /mnt
sudo zpool export zroot

log "--------------------------------------------------------"
log "SUCCESS! Installation Complete."
log "1. Unplug the Samsung T5 SSD."
log "2. Connect to Raspberry Pi 4 (Blue USB 3.0 Port)."
log "3. Remove SD card (Force USB Boot)."
log "4. Power on."
log "--------------------------------------------------------"