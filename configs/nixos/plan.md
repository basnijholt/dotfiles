# Docker Swarm HA Cluster Setup Plan

## Overview

Setting up a 3-node Docker Swarm HA cluster across NixOS machines using agenix for secrets management.

## Architecture

| Host | Role | Interface | Location |
|------|------|-----------|----------|
| hp | Bootstrap manager | br0 | Physical server |
| nuc | Joining manager | br0 | Physical server |
| swarm-vm | Joining manager | eth0 | Incus VM on TrueNAS |

## Configuration

The swarm module uses a simplified single-line API:

```nix
# Bootstrap manager (hp) - creates the cluster
my.swarm.bootstrap = "br0";

# Joining managers (nuc, swarm-vm) - join hp.local:2377
my.swarm.join = "br0";  # or "eth0" for swarm-vm
```

The module is at `optional/docker-swarm.nix` (~90 lines).

## Secrets (agenix)

Tokens are managed with agenix. Files in `secrets/`:
- `swarm-manager.token.age` - manager join token
- `swarm-worker.token.age` - worker join token (for future use)
- `secrets.nix` - maps host SSH keys to secrets

## Deployment Steps

### Step 1: Deploy HP (bootstrap manager)

```bash
# On hp
cd /path/to/dotfiles/configs/nixos
git pull
sudo nixos-rebuild switch --flake .#hp
```

This will:
- Initialize Docker Swarm on br0
- Create tokens at `/root/secrets/swarm-manager.token` and `/root/secrets/swarm-worker.token`

### Step 2: Encrypt the token with agenix

From a machine with agenix and your private key:

```bash
cd configs/nixos/secrets

# Get the token from hp and encrypt it
ssh hp "cat /root/secrets/swarm-manager.token" | agenix -e swarm-manager.token.age

# Commit and push
git add swarm-manager.token.age
git commit -m "Add encrypted swarm manager token"
git push
```

### Step 3: Add host keys to secrets.nix

Before step 2, ensure `secrets/secrets.nix` has the host SSH public keys:

```bash
# Get host keys
ssh-keyscan -t ed25519 hp nuc swarm-vm 2>/dev/null
```

Add them to `secrets/secrets.nix`:
```nix
let
  hp = "ssh-ed25519 AAAA...";
  nuc = "ssh-ed25519 AAAA...";
  swarm-vm = "ssh-ed25519 AAAA...";
in {
  "swarm-manager.token.age".publicKeys = [ hp nuc swarm-vm ];
  "swarm-worker.token.age".publicKeys = [ hp nuc swarm-vm ];
}
```

### Step 4: Deploy joining nodes

```bash
# On nuc
sudo nixos-rebuild switch --flake .#nuc

# On swarm-vm (after creating the VM in Incus)
sudo nixos-rebuild switch --flake .#swarm-vm
```

### Step 5: Verify

```bash
ssh hp "docker node ls"
```

Should show 3 managers, all "Ready".

## Files Modified

| File | Change |
|------|--------|
| `optional/docker-swarm.nix` | New module (~90 lines) |
| `hosts/hp/default.nix` | Added `my.swarm.bootstrap = "br0";` |
| `hosts/nuc/default.nix` | Added `my.swarm.join = "br0";` |
| `hosts/swarm-vm/default.nix` | Added `my.swarm.join = "eth0";` |
| `secrets/secrets.nix` | Host keys for hp, nuc, pc, pi3, pi4 |
| `secrets/swarm-manager.token.age` | Encrypted manager join token |
| `secrets/wifi.age` | Encrypted WiFi credentials |
| `flake.nix` | Added agenix CLI to x86_64 hosts |

## Current State

- [x] Module created and tested (evaluates correctly)
- [x] HP, NUC, swarm-vm configs updated
- [x] Commits on `docker-swarm` branch
- [x] Deploy to HP (creates swarm, generates tokens)
- [x] Encrypt token with agenix
- [x] Deploy to NUC
- [x] Verify cluster (hp=Leader, nuc=Reachable)
- [ ] Create and deploy swarm-vm (3rd manager)

## Git Branch

All changes are on branch `docker-swarm`. Commits:
1. Initial swarm module and host configs
2. Fix hostname: hp.lan → hp.local
3. Compress module: 77 → 42 lines

## Troubleshooting

**Swarm already initialized**: The systemd services are idempotent - they check if already in swarm before init/join.

**Token not found**: Ensure agenix secret is properly encrypted and `secrets.nix` includes the host's public key.

**Can't reach hp.local**: Check mDNS/Avahi is working, or use IP address instead (would require module change).

## Bugs Fixed During Setup

1. **docker not in PATH**: Added `path = [ config.virtualisation.docker.package pkgs.iproute2 pkgs.gawk ]` to systemd service
2. **grep matched 'inactive' as 'active'**: Changed `grep -qE` to `grep -qxE` (match whole line)
3. **Multiple IPv6 addresses on interface**: Extract IPv4 dynamically instead of passing interface name to Docker
4. **Nix `or` operator bug**: `null or "br0"` returns `null` (attribute exists). Fixed with `if/then/else`

## Adding swarm-vm Later

When ready to add the 3rd manager:
```bash
# 1. Create VM in Incus on TrueNAS
# 2. Deploy NixOS to it
# 3. Get its host key and add to secrets/secrets.nix
# 4. Re-key secrets: cd secrets && agenix -r
# 5. Deploy: nixos-rebuild switch --flake .#swarm-vm
# 6. Verify: docker node ls (should show 3 managers)
```
