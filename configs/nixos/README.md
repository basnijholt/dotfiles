# Bas Nijholt's NixOS configs

## 3-Tier Module Architecture

```
configs/nixos/
├── common/           # Tier 1: shared by ALL hosts
├── optional/         # Tier 2: opt-in modules (desktop, audio, virtualization, power, etc.)
├── hosts/            # Tier 3: host-specific (pc, nuc, hp, dev-vm, build-vm)
├── installers/       # ISO builder
└── archive/          # Old migration scripts/notes
```

## Configurations

| Config | Type | Description |
|--------|------|-------------|
| `nixos` | Physical | Desktop/workstation (NVIDIA, Hyprland, AI services) |
| `nuc` | Physical | Media box (Kodi, Btrfs, desktop + power management) |
| `hp` | Physical | Headless server (ZFS, virtualization + power management) |
| `hp-incus` | Incus VM | HP config for Incus VM testing |
| `nuc-incus` | Incus VM | NUC config for Incus VM testing |
| `pc-incus` | Incus VM | PC config for Incus VM testing (GPU services build but won't run) |
| `dev-vm` | Incus VM | Lightweight dev environment (x86_64) |
| `dev-vm-aarch64` | Incus VM | Lightweight dev environment (aarch64, for ARM Macs) |
| `build-vm` | Incus Container | Build server with Harmonia cache (for CUDA/large builds) |
| `installer` | ISO | Minimal installer with SSH enabled |

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

## Nix Cache Server Setup (nix-cache)

See [hosts/nix-cache/README.md](./hosts/nix-cache/README.md) for instructions on setting up the cache server container with Harmonia.
