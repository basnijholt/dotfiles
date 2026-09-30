# Paul's Wyse 5070 Gateway

Gateway to home services via Tailscale. Provides DNS resolution for `*.local` domains and reverse proxies to home network.

**Location:** France, at Paul's (managed remotely from Seattle - changes require caution!)

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

## Deploying

Not comin-managed, so deploy by hand from pc. Activate with `test` first: if the box
drops off the tailnet, a reboot brings back the previous generation. Then `switch`.

```bash
nixos-rebuild test --flake ~/dotfiles/configs/nixos#paul-wyse \
  --target-host basnijholt@100.64.0.35 --sudo --ask-sudo-password --use-substitutes
ssh basnijholt@100.64.0.35 true  # still reachable?
nixos-rebuild switch --flake ~/dotfiles/configs/nixos#paul-wyse \
  --target-host basnijholt@100.64.0.35 --sudo --ask-sudo-password --use-substitutes
```

`--use-substitutes` makes the Wyse download from cache.nixos.org over its own uplink
instead of pulling everything through the tailnet. The eMMC pool is small (about 9 GB
free before a nixpkgs bump, which needs about 4 GB): check `zpool list` first and
collect old generations if it's tight. After a Jellyfin upgrade, its first start can
spend 20 minutes migrating over the rclone mount; `/health` says `Degraded` until then.

## Services

| Service | Purpose |
|---------|---------|
| CoreDNS | Resolves `*.local` → `127.0.0.1` |
| Caddy | Proxies `media.local` → home server via Tailscale |
| Tailscale | Secure tunnel to home network |

## Testing in VM

For testing without hardware, use the `paul-wyse-incus` config. See `incus-overrides.nix` for instructions.

## Troubleshooting

### It turns itself off

The journal showed `Power key pressed short.` before most of the shutdowns, some
within minutes of booting, so a short press of the power button is ignored now
(`optional/power.nix`); holding it still forces the box off. Kernel lockups and
panics reboot it (`panic=10`). The TCO watchdog would catch hard freezes too, but
the BIOS doesn't expose it. For power cuts, set Power Management > AC Recovery to
"Power On" in the BIOS (F2 at boot), so it starts again when the power returns.
Uptime Kuma pings it over Tailscale (100.64.0.35).


### NIC instability

The Realtek RTL8111/8168 NIC uses the `r8169` driver by default. If networking is unstable (link drops, poor throughput), switch to `r8168`:

```nix
# In hardware-configuration.nix, uncomment:
boot.blacklistedKernelModules = [ "r8169" ];
boot.extraModulePackages = [ config.boot.kernelPackages.r8168 ];
```

Then rebuild and reboot.
