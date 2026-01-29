# Paul's Wyse 5070 Gateway

Gateway to home services via Tailscale. Provides DNS resolution for `*.local` domains and reverse proxies to home network.

**Location:** Netherlands (managed remotely from Seattle - changes require caution!)

## Hardware

- Dell Wyse 5070 thin client
- Intel Celeron J4105 (Gemini Lake)
- 4GB DDR4
- 32GB eMMC

## Network Flow

```
Device on LAN → DNS (*.local) → Wyse CoreDNS → Caddy → Tailscale → Home services
```

## Installation

**Build installer ISO:**

```bash
nix build .#nixosConfigurations.paul-wyse-installer.config.system.build.isoImage
cp result/iso/*.iso /tmp/paul-wyse-installer.iso
```

Flash to USB with `dd` or Ventoy, boot the Wyse 5070, then run:

```bash
install-paul-wyse
```

The script handles partitioning (disko), installation, and provides post-install instructions.

## Post-install Setup

1. Reboot and login as `basnijholt` (password: `nixos`)
2. Change password: `passwd`
3. Connect to Tailscale: `sudo tailscale up --login-server https://headscale.nijho.lt`
4. Point router DNS at this machine's IP

## Services

| Service | Purpose |
|---------|---------|
| CoreDNS | Resolves `*.local` → `127.0.0.1` |
| Caddy | Proxies `media.local` → home server via Tailscale |
| Tailscale | Secure tunnel to home network |

## Testing in VM

For testing without hardware, use the `paul-wyse-incus` config. See `incus-overrides.nix` for instructions.

## Troubleshooting

### NIC instability

The Realtek RTL8111/8168 NIC uses the `r8169` driver by default. If networking is unstable (link drops, poor throughput), switch to `r8168`:

```nix
# In hardware-configuration.nix, uncomment:
boot.blacklistedKernelModules = [ "r8169" ];
boot.extraModulePackages = [ config.boot.kernelPackages.r8168 ];
```

Then rebuild and reboot.

### Remote changes (transatlantic!)

This machine is 7,000+ miles away with no physical access. For risky changes (kernel modules, networking):

1. **Don't change preemptively** - only fix what's broken
2. **Use `nixos-rebuild test`** - reverts on reboot (but won't help for driver changes that need reboot)
3. **Have someone local ready** - to select previous generation from boot menu if needed
