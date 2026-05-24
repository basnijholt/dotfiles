# Building aarch64-linux NixOS on macOS

Apple Silicon Macs are `aarch64-darwin`; the VM and Raspberry Pi targets are
`aarch64-linux`. The CPU architecture matches, but macOS still needs a Linux
builder to build Linux derivations.

## Native Linux Builder

To build `aarch64-linux` packages on macOS, enable Determinate Nix's native
Linux builder:

1. Install Determinate Nix.
2. Sign up for FlakeHub and log in with `determinate-nixd auth login`.
3. Make sure your FlakeHub account has native Linux builder access.
4. If the builder is unavailable after login, restart Determinate Nixd.

```bash
determinate-nixd status
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

See Determinate's native Linux builder troubleshooting guide:
<https://docs.determinate.systems/troubleshooting/native-linux-builder/>.

Test the builder with a small `aarch64-linux` derivation:

```bash
nix build --print-build-logs --substituters "" \
  "https://flakehub.com/f/DeterminateSystems/minimal-stdenv/0.1#packages.aarch64-linux.default"
```

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
