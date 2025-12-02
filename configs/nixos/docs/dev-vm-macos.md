# Building aarch64-linux NixOS VM on macOS (ARM)

Run a NixOS development VM (`dev-vm-aarch64`) on an ARM Mac using Incus.

## Quick Start

### 1. Download the installer ISO

```bash
wget -O /tmp/nixos-installer-aarch64-linux.iso \
  "https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-installer-aarch64-linux.iso"
```

### 2. Create and boot the VM

```bash
# Create VM with disk
incus init dev-vm --empty --vm -c limits.cpu=4 -c limits.memory=8GiB
incus config device add dev-vm root disk pool=default size=20GiB

# Attach ISO and boot
incus config device add dev-vm iso disk source=/tmp/nixos-installer-aarch64-linux.iso boot.priority=10
incus start dev-vm
incus console dev-vm
```

### 3. Install NixOS (inside VM console)

```bash
# Partition and format with disko
sudo nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko -- --mode disko \
  --flake 'github:basnijholt/dotfiles?dir=configs/nixos#dev-vm-aarch64'

# Install NixOS
sudo nixos-install --no-root-passwd \
  --flake 'github:basnijholt/dotfiles?dir=configs/nixos#dev-vm-aarch64'

sudo poweroff
```

### 4. Boot the installed system

```bash
incus config device remove dev-vm iso
incus start dev-vm
incus console dev-vm
```

## Why not build disk images directly?

Building disk images with `diskoImages` requires nested virtualization (QEMU inside the Linux builder VM). The Determinate Nix Linux builder lacks KVM support, causing QEMU to fall back to slow software emulation (~10-100x slower), which leads to timeouts and kernel panics.

If you have a Linux machine with KVM (or a remote builder), you can build images directly:

```bash
nix build .#nixosConfigurations.dev-vm-aarch64.config.system.build.diskoImages
incus image import result/main.raw.zst --alias nixos-dev-vm
incus launch nixos-dev-vm dev-vm --vm
```

## Prerequisites (for building aarch64-linux packages)

To build aarch64-linux packages on macOS, configure Determinate Nix's Linux builder:

```bash
sudo mkdir -p /etc/determinate
cat <<EOF | sudo tee /etc/determinate/config.json
{
  "builder": {
    "state": "enabled",
    "memoryBytes": 17179869184,
    "cpuCount": 1
  }
}
EOF
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

Memory values: 8GB=`8589934592`, 16GB=`17179869184`, 32GB=`34359738368`

## Troubleshooting

### Kernel panic during disk image build

Use the ISO installation method instead. See "Why not build disk images directly?" above.

### Cannot access VM console

```bash
incus console dev-vm --type=vga
```

### "no space left on device" during builds

Increase `memoryBytes` in `/etc/determinate/config.json` and restart the daemon.
