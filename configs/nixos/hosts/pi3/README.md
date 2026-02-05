# Raspberry Pi 3 Setup

Simple Pi 3 running from SD card with WiFi.

## Prerequisites

- Raspberry Pi 3
- MicroSD card (8GB+)
- Build machine: Linux or Mac

## Installation

### 1. Create wifi.nix

Create `hosts/pi4/wifi.nix` (shared with Pi 4, gitignored):

```nix
{
  networking.networkmanager.ensureProfiles.profiles."Home-WiFi" = {
    connection = { id = "Home-WiFi"; type = "wifi"; autoconnect = true; };
    wifi = { mode = "infrastructure"; ssid = "YOUR_SSID"; };
    wifi-security = { key-mgmt = "wpa-psk"; psk = "YOUR_PASSWORD"; };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}
```

### 2. Build and flash SD image

```bash
nix build 'path:.#nixosConfigurations.pi3-bootstrap.config.system.build.sdImage' --impure
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. Boot and SSH in

1. Insert SD card
2. Power on, wait ~30 seconds for WiFi
3. `ssh root@pi-bootstrap.local`

### 4. Switch to full config and activate Home Manager

**Pi 3 has only 1GB RAM** - builds must run on your PC to avoid OOM.

From your PC:

```bash
cd ~/dotfiles/configs/nixos
./hosts/pi3/deploy.sh nixos@192.168.1.x
```

Then SSH into the Pi and run the activation command printed by the script.

## Updating

From your PC:

```bash
./hosts/pi3/deploy.sh
# SSH in and run the printed activation command
```

## Troubleshooting

- **No WiFi**: Check `hosts/pi4/wifi.nix` exists
- **Can't SSH**: Verify Pi is powered and connected to your network
