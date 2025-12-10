# Raspberry Pi 3 Setup

Pi 3 on SD card with WiFi. Build on PC (1GB RAM too low).

## Install

1. **Encrypt WiFi credentials** (see [secrets/](../../secrets/))
2. **Flash SD**: `nix build 'path:.#nixosConfigurations.pi3-bootstrap.config.system.build.sdImage' --impure`
3. **Boot**, SSH to `root@pi-bootstrap.local`
4. **Add host key** to `secrets/secrets.nix`, re-key
5. **Deploy from PC**: `./hosts/pi3/deploy.sh`

## Update

```bash
./hosts/pi3/deploy.sh
```
