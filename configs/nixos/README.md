# Bas Nijholt's NixOS configs

## 3-Tier Module Architecture

```
configs/nixos/
├── common/           # Tier 1: shared by ALL hosts
├── optional/         # Tier 2: opt-in modules (desktop, audio, virtualization, power, etc.)
├── hosts/            # Tier 3: host-specific modules
├── installers/       # ISO builder
└── archive/          # Old migration scripts/notes
```

## Configurations

| Config | Type | Description |
|--------|------|-------------|
| `pc` | Physical | Desktop/workstation (NVIDIA, Hyprland, AI services) |
| `nuc` | Physical | Media box (Kodi, Btrfs, desktop + power management) |
| `hp` | Physical | Headless server (ZFS, virtualization + power management) |
| `nas` | Physical | NixOS replacement scaffold for NAS services |
| `hp-incus` | Incus VM | HP config for Incus VM testing |
| `nuc-incus` | Incus VM | NUC config for Incus VM testing |
| `pc-incus` | Incus VM | PC config for Incus VM testing (GPU services build but won't run) |
| `dev-vm` | Incus VM | Lightweight dev environment (x86_64) |
| `dev-lxc` | Incus LXC | Lightweight dev container (x86_64) |
| `mindroom-spouse` | Incus LXC | Companion bot / MindRoom runtime container |
| `mindroom` | Incus LXC | MindRoom lab/runtime container with local Matrix and web services |
| `docker-lxc` | Incus LXC | Docker-focused container (x86_64) |
| `nix-cache` | Incus LXC | Nix cache server with Harmonia (for CUDA/large builds) |
| `hetzner-matrix` | Cloud VPS | Hetzner ARM Tuwunel Matrix homeserver for MindRoom |
| `hetzner-bootstrap` | Bootstrap | Minimal first-stage config for Hetzner ARM installs |
| `hetzner` | Cloud VPS | Minimal Docker Compose host for websites (Hetzner Cloud) |
| `hetzner-saas` | Cloud VPS | Hetzner x86_64 single-node K3s host for MindRoom SaaS |
| `hetzner-saas-bootstrap` | Bootstrap | Minimal first-stage config for Hetzner SaaS installs |
| `paul-wyse` | Physical | Gateway to home services via Tailscale (Dell Wyse 5070) |
| `paul-wyse-incus` | Incus VM | Paul Wyse config for Incus VM testing |
| `pi4` | Physical | Raspberry Pi 4 - lightweight headless server with ZFS on SSD (aarch64) |
| `pi3` | Physical | Raspberry Pi 3 - lightweight headless server with WiFi (aarch64) |
| `pi3-bootstrap` | SD Image | Minimal Pi 3 bootstrap image with WiFi + SSH |
| `pi4-bootstrap` | SD Image | Minimal Pi 4 bootstrap image with WiFi + SSH |
| `installer` | ISO | Minimal installer with SSH enabled |
| `paul-wyse-installer` | ISO | Installer for Paul's Wyse 5070 with auto-install script |

## Quick Commands

```bash
# Build a system
nix build .#nixosConfigurations.hp.config.system.build.toplevel

# Build all Colmena deployment nodes
nix run .#colmena -- build

# Deploy all Colmena deployment nodes
nix run .#colmena -- apply

# Deploy one node or tag
nix run .#colmena -- apply --on nas
nix run .#colmena -- apply --on @home

# Build installer ISO
nix build .#nixosConfigurations.installer.config.system.build.isoImage
cp result/iso/*.iso /tmp/nixos.iso
```

`colmena apply` is the default push-based deployment path for reachable hosts.
The default hive currently includes `pc`, `nuc`, `hp`, `nas`, `pi4`, `docker-lxc`, `nix-cache`, `hetzner`, and `hetzner-matrix`.
The first rollout of the Colmena change itself still needs a manual `nixos-rebuild switch` or the previous pull-based deployment path, because existing hosts need this config once before non-interactive sudo is available for Colmena activation.

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

> **Note:** Default password is `nixos`. Change it after first boot with `passwd basnijholt`.

## Hetzner Cloud Installation

```bash
echo 'HCLOUD_TOKEN="your-token"' > hosts/hetzner/.env  # Create API token at hetzner.cloud
./hosts/hetzner/deploy.py deploy                       # Deploys CAX11 ARM server (€3.29/mo)
```

After deployment, set your password: `ssh basnijholt@<IP>` then `passwd`.

## Nix Cache Server Setup (nix-cache)

See [hosts/nix-cache/README.md](./hosts/nix-cache/README.md) for instructions on setting up the cache server container with Harmonia.

## Paul's Wyse 5070 Gateway (paul-wyse)

See [hosts/paul-wyse/README.md](./hosts/paul-wyse/README.md) for installation and setup instructions.
