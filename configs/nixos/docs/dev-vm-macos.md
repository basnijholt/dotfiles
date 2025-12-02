# Building aarch64-linux NixOS VM on macOS (ARM)

Run a NixOS development VM (`dev-vm-aarch64`) on an ARM Mac using Incus. This requires building an `aarch64-linux` NixOS configuration on `aarch64-darwin` (macOS).

## Prerequisites

macOS cannot natively build Linux packages. We use Determinate Nix's native Linux builder (uses macOS Virtualization framework).

**Note:** The native Linux builder requires early access (as of Dec 2025). Email support@determinate.systems with your FlakeHub username to request access.

## Setup

### 1. Configure builder memory

The builder's virtual disk is provisioned from memory. For large NixOS builds, increase `memoryBytes`:

```bash
sudo mkdir -p /etc/determinate
sudo nano /etc/determinate/config.json
```

Add (adjust based on your Mac's RAM):
```json
{
  "builder": {
    "state": "enabled",
    "memoryBytes": 17179869184,
    "cpuCount": 1
  }
}
```

**Memory values:**
- 8GB (default): `8589934592`
- 16GB: `17179869184`
- 32GB: `34359738368`

**Note:** Keep `cpuCount` at 1 - multiple CPUs with macOS Virtualization framework is typically slower ([source](https://docs.determinate.systems/determinate-nix/)).

### 2. Restart the daemon

```bash
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

### 3. Verify the feature is enabled

```bash
determinate-nixd version
```

Should show `linux-builder` in the enabled features list.

## Build and Run

### Build the disk image

```bash
cd ~/dotfiles/configs/nixos
nix build .#nixosConfigurations.dev-vm-aarch64.config.system.build.diskoImages --print-out-paths
```

### Import into Incus and run

```bash
# Get the output path from the build
RESULT=$(nix build .#nixosConfigurations.dev-vm-aarch64.config.system.build.diskoImages --print-out-paths)

# Import the disk image into Incus
incus image import "$RESULT/main.raw.zst" --alias nixos-dev-vm-aarch64

# Create and start the VM
incus launch nixos-dev-vm-aarch64 dev-vm --vm

# Or with specific resources:
incus launch nixos-dev-vm-aarch64 dev-vm --vm -c limits.cpu=4 -c limits.memory=8GiB
```

## Troubleshooting

### "no space left on device"

Increase `memoryBytes` in `/etc/determinate/config.json` and restart the daemon.

### Restart Determinate Nix daemon

```bash
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```
