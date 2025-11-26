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

The `build-vm` configuration runs a Harmonia binary cache server in an Incus **container** for offloading expensive builds (CUDA, PyTorch, etc.) to a TrueNAS server.

### Step 1: Create Container

```bash
# On TrueNAS (adjust CPU/memory as needed)
incus launch images:nixos/unstable build-vm \
  -c limits.cpu=16 \
  -c limits.memory=24GB
```

> **Note:** This creates a container (not a VM). Containers share the host kernel and have better performance.

### Step 2: Apply NixOS Configuration

```bash
incus exec build-vm -- nixos-rebuild switch \
  --flake "github:basnijholt/dotfiles/main?dir=configs/nixos#build-vm" \
  --option sandbox false
```

> **Note:** `--option sandbox false` is required because Incus containers don't support the kernel namespaces needed for Nix sandboxing. This is configured permanently in the build-vm config.

### Step 3: Generate Cache Signing Key

```bash
incus exec build-vm -- bash -c '
  sudo mkdir -p /var/lib/harmonia
  sudo nix key generate-secret --key-name build-vm-1 > /tmp/key.pem
  sudo mv /tmp/key.pem /var/lib/harmonia/cache-priv-key.pem
  sudo chmod 600 /var/lib/harmonia/cache-priv-key.pem
  sudo systemctl restart harmonia
  echo "Public key (save this):"
  sudo nix key convert-secret-to-public < /var/lib/harmonia/cache-priv-key.pem
'
```

### Step 4: Verify Harmonia is Running

```bash
incus exec build-vm -- systemctl status harmonia
incus exec build-vm -- curl -s http://localhost:5000/nix-cache-info
```

### Step 5: Set Up DNS

Create a DNS record `nix-cache.local` pointing to the container's IP address (or use the IP directly in the next step).

### Step 6: Configure Clients

The cache is already configured in `common/nix.nix`. After merging the harmonia branch, all hosts will use the cache automatically.

### Step 7: Populate the Cache

The auto-build service runs daily and builds all host configurations. To start it immediately:

```bash
incus exec build-vm -- sudo systemctl start nix-auto-build
```

Monitor progress:

```bash
incus exec build-vm -- sudo journalctl -fu nix-auto-build
```

Check timer status:

```bash
incus exec build-vm -- systemctl list-timers nix-auto-build
```

The first build takes several hours (especially CUDA packages). Subsequent builds are fast since most packages are cached.

### Manual Builds

To manually build a specific configuration:

```bash
incus exec build-vm -- bash -c '
  cd /var/lib/nix-auto-build/dotfiles/configs/nixos
  nix build .#nixosConfigurations.nixos.config.system.build.toplevel
'
```
