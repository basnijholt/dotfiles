# Building aarch64-linux NixOS VM on macOS (ARM)

## Goal

Run a NixOS development VM (`dev-vm-aarch64`) on an ARM Mac using Incus. This requires building an `aarch64-linux` NixOS configuration on `aarch64-darwin` (macOS).

## The Problem

macOS cannot natively build Linux packages. You need a Linux builder to compile `aarch64-linux` derivations.

## What We Tried

### 1. Determinate Nix Native Linux Builder (REQUIRES EARLY ACCESS)

Determinate Nix 3.8.4+ introduced a native Linux builder using macOS's Virtualization framework.
See: https://determinate.systems/blog/changelog-determinate-nix-384/

Configuration (add to `/etc/nix/nix.custom.conf`):
```
extra-experimental-features = external-builders
external-builders = [{"systems":["aarch64-linux","x86_64-linux"],"program":"/usr/local/bin/determinate-nixd","args":["builder"]}]
```

**Problem**: Feature is in developer preview (as of Nov 2025). When attempting to use it:
```
Error: failed to set up Native Linux Builder
HTTP status code 400 Bad Request, reply: The Native Linux Builder is not currently available.
Contact support@determinate.systems for more information.
```

**Solution**: Email support@determinate.systems with your FlakeHub username to request early access.

### 2. nix-darwin's linux-builder (BLOCKED)

The cleanest solution would be:
```nix
nix.enable = true;
nix.linux-builder.enable = true;
```

**Problem**: Using Determinate Nix, which conflicts with nix-darwin's nix management. Must use `nix.enable = false`, which disables `nix.linux-builder`.

See: https://docs.determinate.systems/guides/nix-darwin/

### 3. Manual linux-builder with custom nix.conf (FAILED)

Started the linux-builder manually:
```bash
nix run nixpkgs#darwin.linux-builder
```

This starts a VM listening on `localhost:31022`.

Configured `/etc/nix/nix.custom.conf`:
```
builders = ssh-ng://builder@localhost?ssh-options=-p%2031022 aarch64-linux /etc/nix/builder_ed25519
builders-use-substitutes = true
```

Restarted nix daemon:
```bash
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

**Problem**: SSH key permission issue. The key `/etc/nix/builder_ed25519` is only readable by root. The nix daemon runs as root, but the manually-started linux-builder VM may not be configured to accept this key.

### 4. Other SSH builder formats tried

- `ssh-ng://builder@linux-builder` - hostname doesn't resolve
- `ssh-ng://builder@localhost:31022` - wrong port syntax
- `ssh-ng://builder@localhost?ssh-options=-p%2031022` - SSH key mismatch

## Current State (Dec 2025)

- `dev-vm-aarch64` configuration exists in `flake.nix`
- Configuration evaluates correctly (`nix eval` works)
- **Early access granted**: Emailed support@determinate.systems with FlakeHub username to request native Linux builder access - approved
- **Issue**: Default builder VM disk space (8GB) is insufficient for large NixOS builds

## Builder Memory/Disk Configuration

The native Linux builder's virtual disk is provisioned from the memory pool. To build large NixOS configurations, you need to increase `memoryBytes`.

Create `/etc/determinate/config.json`:
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

Restart daemon after changes:
```bash
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

## Build Steps (Resume Here)

### Step 1: Verify the feature is enabled
```bash
determinate-nixd version
```
Should show `linux-builder` in the enabled features list.

### Step 2: Configure builder memory (if needed)
If builds fail with "no space left on device", increase `memoryBytes` in `/etc/determinate/config.json` (see above).

### Step 3: Clean up old config (if any)
Remove any manual builder config from `/etc/nix/nix.custom.conf`:
```bash
sudo nano /etc/nix/nix.custom.conf
# Remove lines containing: builders, external-builders
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

### Step 4: Build the VM
```bash
cd ~/dotfiles/configs/nixos
nix build .#nixosConfigurations.dev-vm-aarch64.config.system.build.toplevel
```

### Step 5: Create Incus VM from the build
```bash
# The build creates a system closure, you'll need to create a disk image
# See: hosts/dev-vm/README.md or use nixos-anywhere for deployment
```

### Step 6: Merge the branch
Once confirmed working:
```bash
git checkout main
git merge macos-vm
git push
```

## Flake Configuration

```nix
# In flake.nix - dev-vm-aarch64 uses lib.nixosSystem directly
# because it needs a different system than the default x86_64-linux

dev-vm-aarch64 = lib.nixosSystem {
  system = "aarch64-linux";
  modules = commonModules ++ [
    { nixpkgs.hostPlatform = "aarch64-linux"; }
    disko.nixosModules.disko
    ./hosts/dev-vm/disko.nix
    ./hosts/dev-vm/default.nix
    ./hosts/dev-vm/hardware-configuration.nix
  ];
};
```

## Key Files

- `/etc/determinate/config.json` - Determinate Nix config (builder memory, cpuCount)
- `/etc/nix/nix.conf` - Main nix config (managed by Determinate)
- `/etc/nix/nix.custom.conf` - Custom nix additions
- `/nix/var/determinate/darwin-builder/` - Builder VM kernel/initrd
- `~/dotfiles/configs/nix-darwin/configuration.nix` - nix-darwin config

## Determinate Nix Service

```bash
# List nix services
sudo launchctl list | grep nix

# Restart nix daemon
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

## x86_64 dev-vm (works)

The x86_64 version (`dev-vm`) can be built on any x86_64-linux machine:
```bash
nix build .#nixosConfigurations.dev-vm.config.system.build.toplevel
```
