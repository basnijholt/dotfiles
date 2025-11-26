# Incus Notes

## Quick Reference

### Installing Incus in NixOS

Incus is available via `nix-shell -p incus`. For `incus-migrate`, you need sudo:

```bash
sudo nix-shell -p incus --run "incus-migrate"
```

### Importing VM Images

Use `incus-migrate` (requires Incus 6.6+) for interactive import:

```bash
incus-migrate
# Prompts:
#   Local server target: yes (Enter)
#   Type: 2 (Virtual Machine)
#   Name: <vm-name>
#   Path: <image.qcow2>
#   UEFI: yes (Enter)
#   Secure Boot: no
#   Begin migration: 1 (Enter)
```

## Networking

### Bridge to Host Network (Wired Ethernet Only)

To attach a VM to the host's physical bridge (e.g., `br0`), use `nictype=bridged` with `parent=`:

```bash
incus stop <vm>
incus config device override <vm> eth0 network= nictype=bridged parent=br0
incus start <vm>
```

**Important**:
- Clear `network=` first, otherwise you get "Cannot use nictype in conjunction with network"
- `network=br0` won't work because br0 is a host bridge, not an Incus network
- WiFi interfaces cannot be bridged (use NAT instead)

## Remote Management

### Enable Remote Access

On **both** machines (each Incus host that should be accessible):

```bash
incus config set core.https_address :8443
```

On the receiving machine, generate a trust token:

```bash
incus config trust add <client-name>
# Copy the token output
```

### Add Remote from Client

```bash
incus remote add <remote-name> <host-ip>:8443
# Paste the trust token when prompted

# Use the remote
incus list <remote-name>:
incus exec <remote-name>:<vm> -- bash
```

### Copying Instances Between Hosts

**Important**: Stop the instance first. Live migration with CRIU often fails.

```bash
incus stop <instance>
incus copy <instance> <remote>:<instance>
incus start <instance>
```

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "Network not found" | Using `network=br0` for host bridge | Use `nictype=bridged parent=br0` |
| "Cannot use nictype with network" | Both properties set | Clear network first: `network=` |
| "Parent device br0 doesn't exist" | No bridge on host (WiFi) | Use default `incusbr0` with NAT |
| "Connection refused" on remote | Incus not listening on network | Set `core.https_address :8443` |
