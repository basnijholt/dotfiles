# dev-vm: NixOS Development VM

Lightweight NixOS development environment for testing and development.

## Configurations

| Config | Platform | Use Case |
|--------|----------|----------|
| `dev-vm` | x86_64-linux | Incus VM on x86_64 hosts |
| `dev-vm-aarch64` | aarch64-linux | QEMU VM on Apple Silicon Macs |

## macOS (Apple Silicon) Installation

On Apple Silicon Macs, use QEMU with Apple's Hypervisor Framework (HVF) for native performance.
Incus does not work on macOS.

### Prerequisites

```bash
brew install qemu
```

### Step 1: Build Custom Installer ISO

Build an aarch64-linux ISO with your SSH key for passwordless access:

```bash
nix build --impure --expr '
  let
    nixpkgs = builtins.getFlake "nixpkgs";
    lib = nixpkgs.lib;
  in
  (lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      (import (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"))
      {
        services.openssh.enable = true;
        services.openssh.settings = {
          PermitRootLogin = "prohibit-password";
          PasswordAuthentication = false;
        };
        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 YOUR_SSH_PUBLIC_KEY"
        ];
      }
    ];
  }).config.system.build.isoImage
' -o /tmp/nixos-aarch64-iso
```

### Step 2: Create VM Disk

```bash
mkdir -p /tmp/nixos-dev-vm
qemu-img create -f qcow2 /tmp/nixos-dev-vm/disk.qcow2 20G
cp /opt/homebrew/opt/qemu/share/qemu/edk2-aarch64-code.fd /tmp/nixos-dev-vm/efi-vars.fd
```

### Step 3: Boot Installer ISO

```bash
qemu-system-aarch64 \
  -name nixos-dev-vm \
  -machine virt,accel=hvf,highmem=on \
  -cpu host \
  -smp 4 \
  -m 16G \
  -drive if=pflash,format=raw,file=/opt/homebrew/opt/qemu/share/qemu/edk2-aarch64-code.fd,readonly=on \
  -drive if=pflash,format=raw,file=/tmp/nixos-dev-vm/efi-vars.fd \
  -drive if=virtio,format=qcow2,file=/tmp/nixos-dev-vm/disk.qcow2 \
  -cdrom /tmp/nixos-aarch64-iso/iso/*.iso \
  -boot d \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -nographic
```

> **Note:** Use 16GB RAM during installation to ensure enough tmpfs space for building.

### Step 4: Partition Disk (via SSH)

```bash
ssh -p 2222 root@localhost

# In the VM:
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
  --mode destroy,format,mount --yes-wipe-all-disks \
  --flake github:basnijholt/dotfiles/main?dir=configs/nixos#dev-vm-aarch64
```

### Step 5: Install NixOS

```bash
# Still in the VM:
nixos-install --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#dev-vm-aarch64' \
  --root /mnt --no-root-passwd --no-channel-copy
```

### Step 6: Boot Installed System

Stop QEMU (Ctrl+A, X) and restart without the ISO:

```bash
qemu-system-aarch64 \
  -name nixos-dev-vm \
  -machine virt,accel=hvf,highmem=on \
  -cpu host \
  -smp 4 \
  -m 8G \
  -drive if=pflash,format=raw,file=/opt/homebrew/opt/qemu/share/qemu/edk2-aarch64-code.fd,readonly=on \
  -drive if=pflash,format=raw,file=/tmp/nixos-dev-vm/efi-vars.fd \
  -drive if=virtio,format=qcow2,file=/tmp/nixos-dev-vm/disk.qcow2 \
  -boot c \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -nographic
```

### Step 7: Connect via SSH

```bash
ssh -p 2222 basnijholt@localhost
```

## File Locations

| File | Purpose |
|------|---------|
| `/tmp/nixos-dev-vm/disk.qcow2` | VM disk image (20GB) |
| `/tmp/nixos-dev-vm/efi-vars.fd` | UEFI variables |

## Important Notes

- The disk device is `/dev/vda` (virtio), not `/dev/sda`
- Use 16GB RAM during installation, 8GB is sufficient for normal use
- SSH user is `basnijholt`, not `root` (root SSH is disabled)
- Default password is `nixos`, change with `passwd basnijholt`

## Troubleshooting

### "No space left on device" during install

Restart QEMU with more RAM (e.g., `-m 16G`). The nix build uses tmpfs which is sized based on RAM.

### SSH connection refused

Wait for the system to fully boot. Check QEMU console output for boot progress.

### Wrong disk device

Ensure `disko.nix` uses `/dev/vda` for virtio disks, not `/dev/sda`.
