# Home Assistant (HAOS) Migration Notes

## Migration Summary
Instead of migrating the existing Proxmox disk (which was messy with partitions), we deployed a fresh official HAOS KVM image and set it up for a clean backup restore.

## Steps Performed

### 1. VM Creation
We used the official generic KVM image (`qcow2.xz`) and imported it using our helper script.

```bash
# Download official image
wget https://github.com/home-assistant/operating-system/releases/download/16.3/haos_ova-16.3.qcow2.xz
unxz haos_ova-16.3.qcow2.xz

# Import to Incus
./migrate-vm.sh haos_ova-16.3.qcow2 haos
```

### 2. Networking Setup
Because the host is on WiFi (`wlp7s0`), bridging was not feasible. We used **Incus Static IPs** combined with **NixOS NAT Forwarding**.

**Incus Configuration:**
We locked the VM to a static internal IP (`10.5.28.161`) so the forwarding rule remains valid.
```bash
incus config device override haos eth0 ipv4.address=10.5.28.161
```

**NixOS Configuration (`hosts/hp/networking.nix`):**
We enabled NAT on the WiFi interface and forwarded port 8123.
```nix
  networking.nat = {
    enable = true;
    externalInterface = "wlp7s0";  # Your WiFi interface
    internalInterfaces = [ "incusbr0" ];
    forwardPorts = [
      { sourcePort = 8123; destination = "10.5.28.161:8123"; proto = "tcp"; }
    ];
  };
```

### 3. Access
*   **Internal VM IP:** `10.5.28.161`
*   **Host Access:** `http://localhost:8123`
*   **Network Access:** `http://192.168.1.143:8123` (or whatever IP the host pulls via DHCP)

## Restoration
To complete the setup:
1.  Open `http://192.168.1.143:8123` in your browser.
2.  Select **"Restore from Backup"** on the onboarding screen.
3.  Upload your Home Assistant backup file.
