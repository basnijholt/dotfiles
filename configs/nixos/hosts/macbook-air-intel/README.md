# Intel MacBook Air Setup

Configuration for MacBook Air (Retina, 13-inch, 2018/2019) - Model `MacBookAir8,1` (T2 Chip).

## Prerequisites

1.  **Custom NixOS Installer**: You **should** build a custom ISO that includes T2 drivers and firmware tools.
    1.  Build the ISO:
        ```bash
        nix build .#nixosConfigurations.installer-mac.config.system.build.isoImage
        ```
    2.  Flash the resulting ISO from `result/iso/` to a USB drive (e.g., `/dev/sda`):
        ```bash
        sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
        ```
        *⚠️ Replace `/dev/sdX` with your actual USB device identifier (check `lsblk`).*
2.  **T2 Security**: You **must** disable Secure Boot and allow booting from external media.
    -   Boot into Internet Recovery Mode (**Option + Command + R**).
    -   Utilities -> Startup Security Utility.
    -   "No Security" and "Allow booting from external media".

## Installation Steps

### 1. Boot the Installer
Insert the USB drive and hold the **Option (Alt)** key while powering on. Select "EFI Boot".

### 2. Connect to Internet
**Option A: USB Tethering (Recommended)**
Connect an Android phone (USB Tethering) or USB-Ethernet adapter. It should autoconnect.

**Option B: WiFi (Requires Firmware Extraction)**
1.  Run the firmware extraction tool:
    ```bash
    sudo get-apple-firmware
    ```
    (Choose **Option 2** to copy from the internal macOS partition).
2.  Reload the WiFi driver:
    ```bash
    sudo modprobe -r brcmfmac_wcc brcmfmac
    sudo modprobe brcmfmac
    ```
3.  Connect using NetworkManager:
    ```bash
    nmcli device wifi list
    nmcli device wifi connect "YOUR_SSID" password "YOUR_PASSWORD"
    ```

Verify connection:
```bash
ping google.com
```

### 3. Install
Switch to root and clone the repo:
```bash
sudo -i
nix-shell -p git
git clone https://github.com/basnijholt/dotfiles /tmp/dotfiles
cd /tmp/dotfiles/configs/nixos
```

Run the installation script:
```bash
./hosts/macbook-air-intel/install.sh
```

### 4. Finish
```bash
reboot
```

## Post-Installation

1.  **WiFi Fix:** After rebooting into the new system, **WiFi will be broken again**. You must run `sudo get-apple-firmware` one more time to install the drivers persistently.
2.  Login and change password:
    ```bash
    passwd basnijholt
    ```