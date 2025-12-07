# Raspberry Pi 4 Setup (pi4)

This configuration sets up a **headless Raspberry Pi 4** booting from an **external SSD** (via USB) using **ZFS**.

Uses the [nixos-raspberrypi](https://github.com/nvmd/nixos-raspberrypi) flake for proper kernel, firmware, and bootloader support.

## Architecture

- **Firmware Partition:** `/boot/firmware` (FAT32) - RPi firmware, U-Boot, config.txt, DTBs
- **Boot Partition:** `/boot` (ext4) - kernel, initrd, extlinux.conf (U-Boot can't read ZFS)
- **Root Filesystem:** ZFS on external SSD

## Prerequisites

1. Raspberry Pi 4
2. MicroSD Card (for bootstrap image)
3. External SSD (Samsung T5 or similar)
4. Build machine with:
   - `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` (for cross-building)
   - Or use Docker on macOS

## Installation Methods

Choose one:
- **Method A: Direct SSD Install** (recommended) - Flash SSD from your Linux PC, then plug into Pi
- **Method B: Bootstrap + nixos-anywhere** - Boot Pi from SD, then install over network

---

## Method A: Direct SSD Install (Recommended)

This is the fastest approach - install directly to SSD from your Linux PC.

### Prerequisites (Linux PC)

```nix
# configuration.nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
boot.supportedFilesystems = [ "zfs" ];
```
Reboot after adding these.

### 1. Configure WiFi

Create `configs/nixos/hosts/pi4/wifi.nix` with your credentials:

```nix
{
  networking.networkmanager.ensureProfiles.profiles = {
    "Home-WiFi" = {
      connection = {
        id = "Home-WiFi";
        type = "wifi";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "YOUR_SSID";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "YOUR_PASSWORD";
      };
      ipv4 = { method = "auto"; };
      ipv6 = { method = "auto"; };
    };
  };
}
```

### 2. Run the Install Script

```bash
# Connect SSD to your Linux PC, then:
cd configs/nixos
./install_pi4_ssd.sh
```

The script will:
1. Partition the SSD (disko)
2. Build the aarch64 system (using binfmt emulation)
3. Install NixOS to the SSD
4. Populate the bootloader (firmware + extlinux)

### 3. Deploy to Pi

1. Unplug SSD from PC
2. Plug into Pi 4 (blue USB 3.0 port)
3. Remove any SD card
4. Power on

The Pi boots directly from SSD and connects to WiFi.

---

## Method B: Bootstrap + nixos-anywhere

Use this if you can't connect the SSD to a Linux PC.

### 1. Configure WiFi

Same as Method A above.

### 2. Build Bootstrap SD Image

#### Option A: Native Linux with binfmt

```bash
nix build .#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage
```

#### Option B: Docker on macOS

```bash
docker volume create nix-cache

docker run --rm -it \
  --platform linux/arm64 \
  -v $(pwd):/work \
  -v nix-cache:/nix \
  -w /work \
  nixos/nix \
  sh -c "
    mkdir -p /nix/var/nix/profiles/per-user/root
    nix --extra-experimental-features 'nix-command flakes' \
      build .#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage \
      --show-trace
  "

# Copy image out
docker run --rm \
  --platform linux/arm64 \
  -v $(pwd):/work \
  -v nix-cache:/nix \
  -w /work \
  nixos/nix \
  sh -c "cp result/sd-image/*.img pi4-bootstrap.img"
```

### 3. Flash & Boot

1. Flash `result/sd-image/*.img` (or `pi4-bootstrap.img`) to MicroSD card
2. Insert SD card + SSD into Pi
3. Power on
4. Pi connects to WiFi automatically (hostname: `pi4-bootstrap`)

### 4. Install to SSD with nixos-anywhere

From your build machine:

```bash
# Replace <PI_IP> with actual IP from your router
nix run github:nix-community/nixos-anywhere -- \
  --flake .#pi4 \
  --build-on-remote \
  root@<PI_IP>
```

### 5. Reboot into Final System

1. Power off Pi
2. Remove SD card
3. Power on - Pi boots from SSD
4. System connects to WiFi (hostname: `pi4`)

## Updating the System

Deploy changes remotely:

```bash
nixos-rebuild switch \
  --flake .#pi4 \
  --target-host root@pi4.local \
  --build-host root@pi4.local
```

## Partition Layout

| Partition | Size | Type | Mount | Purpose |
|-----------|------|------|-------|---------|
| firmware | 256M | FAT32 | /boot/firmware | RPi firmware, U-Boot, config.txt |
| boot | 512M | ext4 | /boot | Kernel, initrd, extlinux.conf |
| zfs | Rest | ZFS | / | Root filesystem with datasets |

## Troubleshooting

### Pi doesn't connect to WiFi

1. Verify `wifi.nix` exists with correct credentials
2. Check that `brcmfmac` module is loaded: `lsmod | grep brcmfmac`
3. Check NetworkManager: `nmcli device status`

### Pi doesn't boot from SSD

1. Check LED patterns:
   - 4 blinks = kernel not found
   - 7 blinks = kernel image bad
2. Connect HDMI to see boot messages
3. Verify U-Boot is loading: check for `u-boot-rpi-arm64.bin` in `/boot/firmware`

### nixos-anywhere fails

The nixos-raspberrypi flake handles bootloader installation properly during NixOS activation.
If it fails, check:
1. SSH access works: `ssh root@<PI_IP>`
2. SSD is detected: `lsblk`
3. Enough disk space for build
