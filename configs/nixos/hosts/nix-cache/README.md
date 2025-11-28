## Nix Cache Server Setup (nix-cache)

The `nix-cache` configuration runs a Harmonia binary cache server in an Incus **container** for offloading expensive builds (CUDA, PyTorch, etc.) to a TrueNAS server.

### Step 1: Create Container

```bash
# On TrueNAS (adjust CPU/memory as needed)
incus launch images:nixos/unstable nix-cache \
  -c limits.cpu=16 \
  -c limits.memory=24GB \
  -c limits.memory.swap=true
```

> **Note:** This creates a container (not a VM). Containers share the host kernel and have better performance.

### Step 2: Apply NixOS Configuration

```bash
incus exec nix-cache -- nixos-rebuild switch \
  --flake "github:basnijholt/dotfiles/main?dir=configs/nixos#nix-cache" \
  --option sandbox false
```

> **Note:** `--option sandbox false` is required because Incus containers don't support the kernel namespaces needed for Nix sandboxing. This is configured permanently in the nix-cache config.

### Step 3: Generate Cache Signing Key

```bash
incus exec nix-cache -- bash -c '
  sudo mkdir -p /var/lib/harmonia
  sudo nix key generate-secret --key-name nix-cache-1 > /tmp/key.pem
  sudo mv /tmp/key.pem /var/lib/harmonia/cache-priv-key.pem
  sudo chmod 600 /var/lib/harmonia/cache-priv-key.pem
  sudo systemctl restart harmonia
  echo "Public key (save this):"
  sudo nix key convert-secret-to-public < /var/lib/harmonia/cache-priv-key.pem
'
```

### Step 4: Verify Harmonia is Running

```bash
incus exec nix-cache -- systemctl status harmonia
incus exec nix-cache -- curl -s http://localhost:5000/nix-cache-info
```

### Step 5: Set Up DNS

Create a DNS record `nix-cache.local` pointing to the container's IP address (or use the IP directly in the next step).

### Step 6: Configure Clients

The cache is already configured in `common/nix.nix`. All hosts will use it automatically.

### Step 7: Populate the Cache

The auto-build service runs daily and builds all host configurations. To start it immediately:

```bash
incus exec nix-cache -- sudo systemctl start nix-auto-build
```

Monitor progress:

```bash
incus exec nix-cache -- sudo journalctl -fu nix-auto-build
```

Check timer status:

```bash
incus exec nix-cache -- systemctl list-timers nix-auto-build
```

The first build takes several hours (especially CUDA packages). Subsequent builds are fast since most packages are cached.

### Manual Builds

To manually build a specific configuration:

```bash
incus exec nix-cache -- bash -c '
  cd /var/lib/nix-auto-build/dotfiles/configs/nixos
  nix build .#nixosConfigurations.pc.config.system.build.toplevel
'
```
