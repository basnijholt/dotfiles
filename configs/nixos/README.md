# Bas Nijholt's NixOS configs

## 3-Tier Module Architecture

```
configs/nixos/
├── common/           # Tier 1: shared by ALL hosts
├── optional/         # Tier 2: opt-in modules (desktop, audio, virtualization, power, etc.)
├── hosts/            # Tier 3: host-specific (pc, nuc, hp)
├── installers/       # ISO builder
└── archive/          # Old migration scripts/notes
```

## Configurations

| Config | Description |
|--------|-------------|
| `nixos` | Desktop/workstation (NVIDIA, Hyprland, AI services) |
| `nuc` | Media box (Kodi, Btrfs, desktop + power management) |
| `hp` | Headless server (ZFS, virtualization + power management) |
| `hp-incus` | HP config for Incus VM testing |
| `nuc-incus` | NUC config for Incus VM testing |
| `pc-incus` | PC config for Incus VM testing (GPU services build but won't run) |
| `dev-vm` | Lightweight dev VM for Incus (familiar env anywhere) |
| `build-vm` | Build server VM with Harmonia cache (for CUDA/large builds) |
| `installer` | Minimal ISO with SSH enabled |

## Quick Commands

```bash
# Build a system
nix build .#nixosConfigurations.hp.config.system.build.toplevel

# Build installer ISO
nix build .#nixosConfigurations.installer.config.system.build.isoImage
cp result/iso/*.iso /tmp/nixos.iso
```

## Install Cheatsheet

Boot from installer ISO, then:

```bash
# Partition and mount (replace #hp with #nuc for NUC)
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
  --mode destroy,format,mount --yes-wipe-all-disks \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#hp

# Install
nixos-install --root /mnt --no-root-passwd \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#hp
```

For Incus VM installation, see the instructions in:
- `hosts/hp/incus-overrides.nix` (HP VM)
- `hosts/nuc/incus-overrides.nix` (NUC VM)
- `hosts/pc/incus-overrides.nix` (PC VM)
- `scripts/create-dev-vm.sh` (dev-vm helper script)

> **Note:** Default password is `nixos`. Change it after first boot with `passwd basnijholt`.

## Build Server Setup (build-vm)

The `build-vm` configuration runs a Harmonia binary cache server for offloading expensive builds (CUDA, PyTorch, etc.) to a TrueNAS Incus VM.

### Initial Setup

```bash
# Create VM on TrueNAS (adjust resources as needed)
incus launch images:nixos/unstable build-vm --vm \
  -c limits.cpu=12 \
  -c limits.memory=24GB \
  -d root,size=200GB

# Apply NixOS configuration
incus exec build-vm -- nixos-rebuild switch \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#build-vm
```

### Generate Cache Signing Key

```bash
# On build-vm
sudo mkdir -p /var/lib/harmonia
sudo nix key generate-secret --key-name build-vm-1 | sudo tee /var/lib/harmonia/cache-priv-key.pem > /dev/null
sudo nix key convert-secret-to-public < /var/lib/harmonia/cache-priv-key.pem
# Save the public key for client configuration
sudo systemctl restart harmonia
```

### Client Configuration

Add to your NixOS config (e.g., `common/nix.nix`):

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org/"
    "http://build-vm:5000"  # Or use IP address
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "build-vm-1:YOUR_PUBLIC_KEY_HERE"
  ];
};
```

### Building and Caching

```bash
# On build-vm: build PC configuration (includes CUDA)
cd ~/dotfiles/configs/nixos
nix flake update
nix build .#nixosConfigurations.nixos.config.system.build.toplevel \
  --out-link /tmp/result-pc \
  --log-format bar-with-logs

# On your PC: rebuild will now pull from cache
sudo nixos-rebuild switch --flake .#nixos
```
