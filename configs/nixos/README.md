# Bas Nijholt's NixOS configs

## 3-Tier Module Architecture

- `common/`: **Tier 1** - Modules shared by ALL hosts (core settings, CLI packages, SSH, user config).
- `optional/`: **Tier 2** - Modules hosts can opt-in to (desktop, audio, virtualization, GUI packages).
- `hosts/`: **Tier 3** - Host-specific modules.
  - `hosts/pc/`: Desktop/workstation (NVIDIA GPU, AI services, 1Password, Slurm, etc.).
  - `hosts/nuc/`: Media box (Kodi, Btrfs).
  - `hosts/hp/`: Headless server (ZFS, no desktop).
- `flake.nix`: Defines the `pc`, `nuc`, and `hp` NixOS configurations.

## Host Roles

- **PC (`nixos` configuration)**: Full workstation with Docker/Incus, NVIDIA GPU, Hyprland desktop, dev toolchains, AI services.
- **NUC (`nuc` configuration)**: Media box with Kodi, Btrfs. Imports all optional modules (desktop, audio, GUI).
- **HP (`hp` configuration)**: Headless server with ZFS. Only imports `optional/virtualization.nix` (no desktop/audio/GUI).

## Workflow Notes

- Build the PC system: `nix build .#nixosConfigurations.nixos.config.system.build.toplevel`
- Build the NUC system: `nix build .#nixosConfigurations.nuc.config.system.build.toplevel`
- Build the HP system: `nix build .#nixosConfigurations.hp.config.system.build.toplevel`

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
