# Intel MacBook Air Setup

Configuration for an Intel-based MacBook Air using ZFS and Disko.

## Prerequisites

1.  **NixOS Installer**: [Download](https://nixos.org/download.html) the Minimal ISO image (x86_64).
2.  **USB Drive**: Flash the ISO onto a USB drive (e.g., using `dd` or Etcher).
3.  **T2 Security (If applicable)**: If the MacBook Air has a T2 chip (2018 or later), boot into Recovery Mode (Command + R) -> Utilities -> Startup Security Utility -> Allow booting from external media and Disable Secure Boot.

## Installation Steps

### 1. Boot the Installer
Insert the USB drive and hold the **Option (Alt)** key while powering on. Select "EFI Boot" (or the USB drive).

### 2. Connect to WiFi
If using the graphical installer, use the UI. For the minimal installer:

```bash
# Start wpa_supplicant if not running
systemctl start wpa_supplicant
wpa_cli
> scan
> scan_results
> add_network
> 0
> set_network 0 ssid "YOUR_SSID"
> set_network 0 psk "YOUR_PASSWORD"
> enable_network 0
> quit
```
Verify connection with `ping google.com`.

### 3. Prepare the Environment
Switch to root:
```bash
sudo -i
```

### 4. Clone the Configuration
```bash
nix-shell -p git
git clone https://github.com/basnijholt/dotfiles /tmp/dotfiles
cd /tmp/dotfiles/configs/nixos
```

### 5. Partition and Mount (Disko)
Run Disko to create the partition table and mount the ZFS datasets.

**⚠️ WARNING**: This will format the disk `/dev/sda`. Verify your disk identifier with `lsblk`. If your disk is NVMe (e.g., `nvme0n1`), edit `hosts/macbook-air-intel/disko.nix` first.

```bash
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/macbook-air-intel/disko.nix
```

### 6. Install NixOS
Install the system using the flake configuration.

```bash
nixos-install --flake .#macbook-air-intel
```

When prompted, set the root password.

### 7. Finish
```bash
reboot
```

## Post-Installation

1.  Login.
2.  Change your user password:
    ```bash
    passwd basnijholt
    ```
3.  Check ZFS status:
    ```bash
    zpool status
    ```
