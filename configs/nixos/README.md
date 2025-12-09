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
| `dev-vm` | Lightweight dev VM for Incus x86_64 (familiar env anywhere) |
| `dev-lxc` | Lightweight dev LXC container for Incus x86_64 (familiar env anywhere) |
| `nix-cache` | Nix cache server container with Harmonia (for CUDA/large builds) |
| `pi3` | Raspberry Pi 3 - lightweight headless server (aarch64) |
| `pi4` | Raspberry Pi 4 - lightweight headless server (aarch64) |
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
  --option substituters "http://nix-cache.local:5000 https://cache.nixos.org https://nix-community.cachix.org https://cache.nixos-cuda.org" \
  --option trusted-public-keys "build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#hp
```

For Incus VM installation, see the instructions in:
- `hosts/hp/incus-overrides.nix` (HP VM)
- `hosts/nuc/incus-overrides.nix` (NUC VM)
- `hosts/pc/incus-overrides.nix` (PC VM)
- `scripts/create-dev-vm.sh` (dev-vm helper script)

> **Note:** Default password is `nixos`. Change it after first boot with `passwd basnijholt`.

## Nix Cache Server Setup (nix-cache)

See [hosts/nix-cache/README.md](./hosts/nix-cache/README.md) for instructions on setting up the cache server container with Harmonia.
