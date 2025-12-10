# Raspberry Pi 3 Setup

Simple Pi 3 running from SD card with WiFi.

## Prerequisites

- Raspberry Pi 3
- MicroSD card (8GB+)
- Build machine: Linux or Mac

## Installation

### 1. Configure WiFi

Set your SSID in `hosts/pi3/default.nix`:

```nix
my.wifi.ssid = "YourNetworkName";
```

Encrypt your WiFi password (shared with pi4):

```bash
cd configs/nixos/secrets
echo "WIFI_PSK=yourpassword" | agenix -e wifi-psk.age
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

### 4. Add host key and deploy

**Pi 3 has only 1GB RAM** - builds must run on your PC to avoid OOM.

Get the host key and add to `secrets/secrets.nix`:

```bash
ssh-keyscan -t ed25519 pi-bootstrap.local 2>/dev/null
# Add key to secrets/secrets.nix, then re-key:
cd configs/nixos/secrets && agenix -r
```

Deploy from your PC:

```bash
./hosts/pi3/deploy.sh nixos@192.168.1.x
# SSH in and run the printed activation command
```

## Updating

From your PC:

```bash
./hosts/pi3/deploy.sh
# SSH in and run the printed activation command
```

## Troubleshooting

- **No WiFi**: Check `my.wifi.ssid` is set in `hosts/pi3/default.nix`
- **Can't SSH**: Verify Pi is powered and connected to your network
