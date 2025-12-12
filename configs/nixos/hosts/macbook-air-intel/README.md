# Intel MacBook Air Setup

Configuration for MacBook Air (Retina, 13-inch, 2018/2019) - Model `MacBookAir8,1` (T2 Chip).

## Prerequisites

1.  **Custom NixOS Installer**: You **should** build a custom ISO that includes T2 drivers (keyboard/trackpad support) and your WiFi credentials.
    1.  Create `hosts/macbook-air-intel/wifi.nix` from `hosts/macbook-air-intel/wifi.example.nix` and add your SSID/Password.
    2.  Build the ISO:
        ```bash
        nix build .#nixosConfigurations.installer.config.system.build.isoImage --impure
        ```
    3.  Flash the resulting ISO from `result/iso/` to a USB drive.
2.  **T2 Security**: You **must** disable Secure Boot and allow booting from external media.
    -   Boot into Recovery Mode (Command + R).
    -   Utilities -> Startup Security Utility.
    -   "No Security" and "Allow booting from external media".

## Installation Steps

### 1. Boot the Installer
Insert the USB drive and hold the **Option (Alt)** key while powering on. Select "EFI Boot".

### 2. Verify WiFi Connection
Since the custom ISO was built with your WiFi credentials, it should connect automatically.

Verify connection:
```bash
ping google.com
```

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

**⚠️ WARNING**: This will format the internal T2 NVMe drive `/dev/nvme0n1`. Verify with `lsblk`.

```bash
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/macbook-air-intel/disko.nix
```

### 6. Install NixOS
Install the system using the flake configuration. This will pull in the T2 specific kernel and drivers.

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
