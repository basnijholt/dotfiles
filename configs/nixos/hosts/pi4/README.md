# Raspberry Pi 4 Setup

Headless Pi 4 with external SSD (ZFS) and WiFi.

## Install

1. **Encrypt WiFi credentials** (see [secrets/](../../secrets/))
2. **Flash bootstrap SD**: `nix build 'path:.#nixosConfigurations.pi4-bootstrap.config.system.build.sdImage' --impure`
3. **Boot**, SSH to `root@pi-bootstrap.local`
4. **Install to SSD**: `./hosts/pi4/install-ssd.sh`
5. **Remove SD**, reboot from SSD
6. **Add host key** to `secrets/secrets.nix`, re-key, rebuild

## Update

```bash
nixos-rebuild switch --flake .#pi4 --target-host root@pi4.local
```
