# hetzner-matrix

Public Matrix homeserver ([Tuwunel](https://github.com/mindroom-ai/mindroom-tuwunel), MindRoom fork) on Hetzner Cloud ARM VPS with [Cinny](https://github.com/mindroom-ai/mindroom-cinny) web client.

Users run [MindRoom](https://github.com/mindroom-ai/mindroom) locally and connect to this server.

## Deploy

From `~/dotfiles/configs/nixos`:

```bash
# 1. Create .env with your Hetzner Cloud API token
echo "HCLOUD_TOKEN=your-token" > hosts/hetzner-matrix/.env

# 2. Push config changes (deploy uses GitHub flake)
git -C ~/dotfiles push

# 3. Deploy (two-stage: bootstrap first, then full host config)
./hosts/hetzner-matrix/deploy.py deploy hetzner-matrix --bootstrap hetzner-bootstrap --type cax21 --location nbg1
```

If a previous failed server already exists, recreate it:

```bash
./hosts/hetzner-matrix/deploy.py deploy hetzner-matrix --bootstrap hetzner-bootstrap --delete --type cax21 --location nbg1
```

## Post-deploy setup

### DNS

Create A records pointing to the server IP:
- `mindroom.chat` - website + Matrix `.well-known` delegation
- `chat.mindroom.chat` - Cinny web client

### Tuwunel config (live file)

Tuwunel reads runtime config from:

`/var/lib/tuwunel/tuwunel.toml`

This file is not generated from Nix. Edit it directly on the server and restart Tuwunel.

Set the Matrix identity domain to apex:

```toml
server_name = "mindroom.chat"
```

With this setup, user IDs are `@user:mindroom.chat`, and client traffic goes directly to `https://mindroom.chat/_matrix/*` (with `.well-known` served by Caddy).

Important: changing `server_name` on an existing Tuwunel database is not supported. Set this before first real use, or wipe/recreate the Matrix database first.

### Tuwunel binary (GitHub release)

Update Tuwunel directly on the server from the latest GitHub release:

```bash
sudo -u tuwunel -H bash -lc '
  set -euo pipefail
  repo="mindroom-ai/mindroom-tuwunel"
  asset_url="$(
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
      | jq -r ".assets[] | select(.name | test(\"linux-aarch64.tar.gz$\")) | .browser_download_url" \
      | head -n1
  )"
  test -n "$asset_url"
  tmp="$(mktemp -d)"
  trap "rm -rf \"$tmp\"" EXIT
  curl -fsSL "$asset_url" -o "$tmp/tuwunel.tar.gz"
  tar -xzf "$tmp/tuwunel.tar.gz" -C "$tmp"
  install -m 0755 -o tuwunel -g tuwunel "$tmp/tuwunel" /var/lib/tuwunel/bin/tuwunel.real
'
sudo systemctl restart tuwunel
```

### Registration token

```bash
sudo bash -c '
  echo "your-secret-token" > /var/lib/tuwunel/registration-token
  chown tuwunel:tuwunel /var/lib/tuwunel/registration-token
  chmod 600 /var/lib/tuwunel/registration-token
'
sudo systemctl restart tuwunel
```

### SSO (Google, GitHub, Apple)

For each provider, create an OAuth app and place the client secret on the server:

Google:

```bash
echo "your-google-secret" | sudo tee /var/lib/tuwunel/sso-google-secret
```

GitHub:

```bash
echo "your-github-secret" | sudo tee /var/lib/tuwunel/sso-github-secret
```

Apple:

```bash
echo "your-apple-secret" | sudo tee /var/lib/tuwunel/sso-apple-secret
```

Then set ownership/permissions:

```bash
sudo chown tuwunel:tuwunel /var/lib/tuwunel/sso-*-secret
sudo chmod 600 /var/lib/tuwunel/sso-*-secret
```

Set callback URLs to:

```text
https://mindroom.chat/_matrix/client/unstable/login/sso/callback/<client_id>
```

Update provider `client_id`, `issuer_url` (for Apple), and `callback_url` in `/var/lib/tuwunel/tuwunel.toml`, then restart:

```bash
sudo systemctl restart tuwunel
```

### Cinny web client

Build and deploy the MindRoom Cinny fork:

```bash
cd /var/www/cinny
git clone https://github.com/mindroom-ai/mindroom-cinny . || true
git pull --ff-only
npm ci
npm run build
```

### mindroom.chat website

Deploy your apex website to:

`/var/www/mindroom`

Caddy serves this directory for `https://mindroom.chat`, except for `/.well-known/matrix/server` and `/.well-known/matrix/client`, which are handled directly for Matrix delegation.

### ZFS host ID

After first deploy, generate a unique host ID and update `default.nix`:

```bash
head -c4 /dev/urandom | od -A none -t x4 | tr -d " "
```

## Rebuild

For NixOS config changes:

```bash
nixos-rebuild switch --flake ~/dotfiles/configs/nixos#hetzner-matrix
```

## Destroy

```bash
./hosts/hetzner-matrix/deploy.py destroy hetzner-matrix
```
