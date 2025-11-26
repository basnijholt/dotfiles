# Home Assistant (HAOS) Migration Notes

## Quick Install (Incus 6.6+)

```bash
# Download HAOS image
wget https://github.com/home-assistant/operating-system/releases/download/16.3/haos_ova-16.3.qcow2.xz
unxz haos_ova-16.3.qcow2.xz

# Interactive import (requires root)
sudo nix-shell -p incus --run "incus-migrate"
# Prompts:
#   Local server target: yes (Enter)
#   Type: 2 (Virtual Machine)
#   Name: haos
#   Path: haos_ova-16.3.qcow2
#   UEFI: yes (Enter)
#   Secure Boot: no
#   Begin migration: 1 (Enter)

# Start
incus start haos
```

## Networking Setup

### Option 1: Bridge (recommended if host has wired ethernet)

Attach the VM to the host's bridge so it gets its own IP from the network:

```bash
incus stop haos
incus config device override haos eth0 network= nictype=bridged parent=br0
incus start haos
```

If DHCP doesn't work, set a static IP inside HAOS (login as `root`, no password):

```bash
ha network update enp5s0 --ipv4-method static --ipv4-address 192.168.1.200/24 --ipv4-gateway 192.168.1.1
```

### Option 2: NAT (if host is on WiFi)

Because WiFi (`wlp7s0`) can't bridge, use **Incus Static IPs** combined with **NixOS NAT Forwarding**.

**Incus Configuration:**
```bash
incus config device override haos eth0 ipv4.address=10.5.28.161
```

**NixOS Configuration (`hosts/pc/networking.nix`):**
```nix
networking.nat = {
  enable = true;
  externalInterface = "wlp7s0";
  internalInterfaces = [ "incusbr0" ];
  forwardPorts = [
    { sourcePort = 8123; destination = "10.5.28.161:8123"; proto = "tcp"; }
  ];
};
```

## Access

- **Internal VM IP:** `10.5.28.161`
- **Host Access:** `http://localhost:8123`
- **Network Access:** `http://<host-ip>:8123`

## VM Configuration

### Memory

HAOS needs at least 4GB RAM (more if you have many add-ons):

```bash
incus stop haos
incus config set haos limits.memory=4GB
incus start haos
```

### Disk Size

Expand the root disk if you run out of space:

```bash
incus stop haos
incus config device override haos root size=64GB
incus start haos
```

### USB Passthrough (Zigbee/Z-Wave sticks)

First find the vendor/product ID on the host:

```bash
nix-shell -p usbutils --run "lsusb"
# Example output: ID 10c4:ea60 Silicon Labs CP210x UART Bridge
```

Then add the USB device to the VM:

```bash
incus stop haos
incus config device add haos zigbee usb vendorid=10c4 productid=ea60
incus start haos
```

Verify inside HAOS:

```bash
incus console haos
# Login as root
ls -la /dev/ttyUSB0
```

Common Zigbee stick IDs:
- Sonoff Zigbee 3.0 (CP2102N): `10c4:ea60`
- Sonoff Zigbee 3.0 (CH9102): `1a86:55d4`
- ConBee II: `1cf1:0030`
- CC2531: `0451:16a8`

## Restoration

1. Open `http://<host-ip>:8123` in your browser.
2. Select **"Restore from Backup"** on the onboarding screen.
3. Upload your Home Assistant backup file.
