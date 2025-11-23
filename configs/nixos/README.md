# Bas Nijholt's NixOS configs

- `modules/`: Shared modules every host imports by default (core system settings, shared packages, services, desktop profile).
- `hosts/pc/`: Desktop/workstation-specific modules (boot, disk layout, nixpkgs overlay, workstation packages, 1Password, GPU, AI extras, Slurm, etc.).
- `hosts/nuc/`: NUC-specific overrides (networking, Kodi packages, etc.).
- `hosts/hp/`: HP-specific overrides (networking, Kodi packages, ZFS, etc.).
- `flake.nix`: Defines the `pc`, `nuc`, and `hp` NixOS configurations on top of shared modules.

## Host Roles

- **PC (`nixos` configuration)**: Full workstation with Docker/Incus, GPU, Hyprland desktop, dev toolchains, AI services. Only this host inherits the heavy packages/modules under `hosts/pc/`.
- **NUC (`nuc` configuration)**: Lightweight dev + media box. Shares basic packages and services but has its own networking tweaks and skips workstation-only modules.
- **HP (`hp` configuration)**: Similar to NUC (lightweight dev + media box) but uses ZFS instead of Btrfs.

## Workflow Notes

- Build the PC system: `nix build .#nixosConfigurations.nixos.config.system.build.toplevel`
- Build the NUC system: `nix build .#nixosConfigurations.nuc.config.system.build.toplevel`
- Build the HP system: `nix build .#nixosConfigurations.hp.config.system.build.toplevel`
- Host-specific overlays live under `hosts/<name>/` to keep shared modules tidy.

## Quick Install Cheatsheet

### NUC Install

When the Intel NUC is booted from the minimal installer ISO, run these two commands over SSH to rebuild the disk layout and install the `nuc` system:

```bash
nix --extra-experimental-features 'nix-command flakes' run --refresh \
  github:nix-community/disko -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#nuc

nixos-install \
  --root /mnt \
  --no-root-passwd \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#nuc
```

The first wipes `/dev/disk/by-id/nvme-CT4000P3PSSD8_2344E884093A`, recreates the GPT/Btrfs layout, and mounts everything under `/mnt`. The second populates `/mnt` with the `nuc` configuration; once it finishes, reboot into the freshly installed system.

### HP Install

Similar to the NUC, but for the HP machine (uses ZFS):

```bash
nix --extra-experimental-features 'nix-command flakes' run --refresh \
  github:nix-community/disko -- \
  --mode destroy,format,mount \
  --yes-wipe-all-disks \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#hp

nixos-install \
  --root /mnt \
  --no-root-passwd \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#hp
```

### Rebuilding the Installer ISO

```bash
nix build .#nixosConfigurations.installer.config.system.build.isoImage
sudo dd if=result/iso/nixos-minimal-25.11.20251002.7df7ff7-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Replace `/dev/sdX` with the target USB device. The ISO boots with SSH enabled and `root`’s console password set to `nixos`.

> **Warning**
> The baked-in password for the `basnijholt` account is `nixos`. Change it immediately after the first boot with:
>
> ```bash
> passwd basnijholt
> ```
>
> If you never set a new password you’ll be stuck with the published default, and anyone with SSH access plus your key would still need the password for sudo.
