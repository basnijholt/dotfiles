# hetzner-matrix

Public Matrix homeserver ([Tuwunel](https://github.com/mindroom-ai/mindroom-tuwunel), MindRoom fork) on Hetzner Cloud ARM VPS with [Cinny](https://github.com/mindroom-ai/mindroom-cinny) web client.

Users run [MindRoom](https://github.com/mindroom-ai/mindroom) locally and connect to this server.

## Deploy

```bash
# 1. Create .env with your Hetzner Cloud API token
echo "HCLOUD_TOKEN=your-token" > hosts/hetzner-matrix/.env

# 2. Commit + push config changes (deploy uses GitHub flake)
git -C ~/dotfiles push

# 3. Deploy (two-stage: bootstrap first, then full config)
./hosts/hetzner-matrix/deploy.py deploy hetzner-matrix --bootstrap hetzner-bootstrap --type cax21 --location nbg1
```

This host is intended to use a two-stage install:
- Stage 1: `hetzner-bootstrap` (minimal system that fits rescue-mode RAM limits)
- Stage 2: switch to full `hetzner-matrix` on the installed system (disk-backed `/nix`)

If a previous failed server already exists, recreate it:
```bash
./hosts/hetzner-matrix/deploy.py deploy hetzner-matrix --bootstrap hetzner-bootstrap --delete --type cax21 --location nbg1
```

## Post-deploy setup

### DNS

Create A records pointing to the server IP:
- `matrix.mindroom.chat` — Matrix homeserver API
- `chat.mindroom.chat` — Cinny web client

### Registration token

```bash
ssh basnijholt@<server-ip>
sudo bash -c '
  echo "your-secret-token" > /var/lib/tuwunel/registration-token
  chown tuwunel:tuwunel /var/lib/tuwunel/registration-token
  chmod 600 /var/lib/tuwunel/registration-token
'
sudo systemctl restart tuwunel
```

### SSO (Google, GitHub, Apple)

For each provider, create an OAuth app and place the client secret on the server:

**Google** ([console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials)):
```bash
echo "your-google-secret" | sudo tee /var/lib/tuwunel/sso-google-secret
```

**GitHub** ([github.com/settings/developers](https://github.com/settings/developers)):
```bash
echo "your-github-secret" | sudo tee /var/lib/tuwunel/sso-github-secret
```

**Apple** ([developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/serviceId)):
```bash
echo "your-apple-secret" | sudo tee /var/lib/tuwunel/sso-apple-secret
```

Then for all secret files:
```bash
sudo chown tuwunel:tuwunel /var/lib/tuwunel/sso-*-secret
sudo chmod 600 /var/lib/tuwunel/sso-*-secret
```

Set the callback URL for each provider to:
```
https://matrix.mindroom.chat/_matrix/client/unstable/login/sso/callback/<client_id>
```

Update the `client_id` and `callback_url` values in `default.nix`, then rebuild.

### Cinny web client

Build and deploy the MindRoom Cinny fork:

```bash
ssh basnijholt@<server-ip>
cd /var/www/cinny
git clone https://github.com/mindroom-ai/mindroom-cinny .
npm ci && npm run build
# Caddy serves dist/ automatically at chat.mindroom.chat
```

To update Cinny later:
```bash
cd /var/www/cinny && git pull && npm ci && npm run build
```

### ZFS host ID

After first deploy, generate a unique host ID and update `default.nix`:

```bash
head -c4 /dev/urandom | od -A none -t x4 | tr -d ' '
```

## Rebuild

After config changes:

```bash
nixos-rebuild switch --flake .#hetzner-matrix --target-host basnijholt@<server-ip>
```

## Destroy

```bash
./hosts/hetzner-matrix/deploy.py destroy hetzner-matrix
```
