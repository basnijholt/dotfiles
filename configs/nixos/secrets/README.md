# Secrets (agenix)

Encrypted with host SSH keys. Decrypted at boot to `/run/agenix/`.

## Setup

1. Get host keys: `ssh-keyscan -t ed25519 <host>`
2. Add to `secrets.nix`
3. Encrypt: `agenix -e <secret>.age`
4. Re-key after changes: `agenix -r`

## Secrets

| File | Format | Used by |
|------|--------|---------|
| `wifi.age` | `WIFI_SSID=...\nWIFI_PSK=...` | pi3, pi4 |
| `swarm-manager.token.age` | token string | hp, nuc, swarm-vm |
| `swarm-worker.token.age` | token string | workers |

## Quick Reference

```bash
# WiFi
echo -e "WIFI_SSID=MyNetwork\nWIFI_PSK=secret" | agenix -e wifi.age

# Swarm (after hp init - tokens stored at /root/secrets/)
ssh hp "sudo cat /root/secrets/swarm-manager.token" | agenix -e swarm-manager.token.age
ssh hp "sudo cat /root/secrets/swarm-worker.token" | agenix -e swarm-worker.token.age
```
