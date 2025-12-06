# Raspberry Pi 4 Setup (pi4)

This configuration sets up a **headless Raspberry Pi 4** booting from an **external SSD** (via USB) using **ZFS**.

## Architecture
*   **Boot:** SD Card (Bootstrap image with pre-configured WiFi & SSH).
*   **Root Filesystem:** ZFS on external SSD (`/dev/disk/by-id/usb-Samsung_Portable_SSD_T5_...`).
*   **Network:** WiFi (Pre-configured) or Ethernet.

## Prerequisites
1.  Raspberry Pi 4.
2.  MicroSD Card.
3.  External SSD (target drive).
4.  Docker (on your Mac).

## Installation Steps

### 1. Configure WiFi
Ensure `configs/nixos/hosts/pi4/wifi.nix` exists with your real credentials.
The build process will **bake these credentials into the SD image**, so the Pi connects automatically on first boot.

### 2. Build Bootstrap Image (using Docker)
Since we are on macOS (aarch64-darwin) and targeting Linux (aarch64-linux), we use Docker to build the image natively.

**Run this command block:**

```bash
# 1. Create a persistent volume for the Nix store (avoids re-downloading on every build)
docker volume create nix-cache

# 2. Build the image inside a container
docker run --rm -it \
  --platform linux/arm64 \
  -v $(pwd):/work \
  -v nix-cache:/nix \
  -w /work \
  nixos/nix \
  sh -c "
    # Ensure profile dir exists
    mkdir -p /nix/var/nix/profiles/per-user/root
    
    # Build the system image (using --impure to read wifi.nix)
    nix --extra-experimental-features 'nix-command flakes' \
      build .#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage \
      --impure \
      --show-trace
  "

# 3. Copy the image out (workaround for broken symlinks)
docker run --rm \
  --platform linux/arm64 \
  -v $(pwd):/work \
  -v nix-cache:/nix \
  -w /work \
  nixos/nix \
  sh -c "cp result/sd-image/*.img pi4-bootstrap.img"
```

You should now have `pi4-bootstrap.img` in your current directory.

### Verify Image Content (Optional)
To verify that your WiFi credentials (SSID) are correctly baked into the image without flashing it:

```bash
docker run --rm --privileged \
  --platform linux/arm64 \
  -v $(pwd)/pi4-bootstrap.img:/image.img \
  nixos/nix \
  sh -c "
    nix-env -iA nixpkgs.e2fsprogs nixpkgs.util-linux nixpkgs.gnugrep nixpkgs.gawk >/dev/null 2>&1
    
    START=\$(fdisk -l /image.img | grep 'image.img2' | awk '{ if (\$2 == \"*\") print \$3; else print \$2 }')
    OFFSET=\$((START * 512))
    mkdir -p /mnt
    mount -o loop,offset=\$OFFSET /image.img /mnt
    
    echo '--- Grepping store for ssid= ---'
    grep -r 'ssid=' /mnt/nix/store 2>/dev/null | head -n 5
    
    umount /mnt
  "
```

### 3. Flash & Boot
1.  Flash `pi4-bootstrap.img` to your MicroSD card (BalenaEtcher or `dd`).
2.  Insert SD card + SSD into Pi.
3.  Power on.
4.  The Pi will boot and connect to your WiFi (check router for IP, hostname `pi4-bootstrap`).

### 4. Install to SSD
Run `nixos-anywhere` from your Mac. It will connect to the running bootstrap system and install the final ZFS configuration to the SSD.

```bash
# Replace <PI_IP_ADDRESS> with the actual IP
# User is 'nixos' (password 'nixos') or 'root' (if you added keys)
# Note: pi4-bootstrap has your SSH keys from common/user.nix baked in.
nix --extra-experimental-features 'nix-command flakes' run --impure github:nix-community/nixos-anywhere -- \
  --flake .#pi4 \
  --build-on remote \
  root@<PI_IP_ADDRESS>
```

### 5. Finish
1.  The Pi will reboot into the new ZFS system on the SSD.
2.  It should reconnect to WiFi automatically (credentials are also in the final system).
