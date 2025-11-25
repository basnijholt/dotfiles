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

Because the host is on WiFi (`wlp7s0`), bridging was not feasible. We used **Incus Static IPs** combined with **NixOS NAT Forwarding**.

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

## Restoration

1. Open `http://<host-ip>:8123` in your browser.
2. Select **"Restore from Backup"** on the onboarding screen.
3. Upload your Home Assistant backup file.
