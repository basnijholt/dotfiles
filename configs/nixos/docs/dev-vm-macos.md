# Building aarch64-linux NixOS on macOS

Apple Silicon Macs are `aarch64-darwin`; the VM and Raspberry Pi targets are
`aarch64-linux`. The CPU architecture matches, but macOS still needs a Linux
builder to build Linux derivations.

## Native Linux Builder

To build `aarch64-linux` packages on macOS, configure Determinate Nix's native
Linux builder:

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

Memory values: 8GB=`8589934592`, 16GB=`17179869184`, 32GB=`34359738368`.

## Development VM

On macOS, use QEMU with Apple's Hypervisor Framework for `dev-vm-aarch64`; Incus
does not run natively on macOS. See `hosts/dev-vm/README.md` for the full QEMU
installation flow.

The VM configuration can be evaluated with:

```bash
nix eval .#nixosConfigurations.dev-vm-aarch64.config.nixpkgs.hostPlatform.system --raw
```

Building it requires the Linux builder:

```bash
nix build .#nixosConfigurations.dev-vm-aarch64.config.system.build.toplevel
```

## Disk Images

Building disk images with `diskoImages` requires nested virtualization (QEMU
inside the Linux builder VM). The Determinate Nix Linux builder does not provide
KVM for that nested QEMU workload, so disk-image builds can fall back to slow
software emulation and fail.

If you have a Linux machine with KVM, build images there:

```bash
nix build .#nixosConfigurations.dev-vm-aarch64.config.system.build.diskoImages
```

## Raspberry Pi

The same Linux builder is also what makes local Mac builds of the Raspberry Pi 4
configuration practical:

```bash
nix build 'path:.#nixosConfigurations.pi4.config.system.build.toplevel' --impure
```
