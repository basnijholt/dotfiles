# Nix

On a fresh macOS machine, install [Homebrew](https://brew.sh/) first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install [Determinate Nix](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#determinate-nix-installer):

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

Then run:

```bash
nix run nix-darwin -- switch --flake ~/dotfiles/configs/nix-darwin
```

or use the alias:

```bash
nixswitch
```

The always-on M2 imports imessage.nix to install a pinned official bridge and run it as a user LaunchAgent.
Its private config.yaml and database live in ~/Library/Application Support/mautrix-imessage/ and stay outside the Nix store.
This Mac's existing configuration targets @basnijholt:mindroom.chat and requires encrypted Matrix rooms.
On a replacement Mac, securely copy config.yaml to the same directory with mode 0600; its tokens must match configs/nixos/hosts/hetzner-matrix/secrets/imessage-appservice-env.age.

Apply the Mac configuration with sudo darwin-rebuild switch --flake "path:$HOME/dotfiles/configs/nix-darwin#basnijholt-macbook-pro-m2" and apply the server configuration under configs/nixos/hosts/hetzner-matrix too.
Grant Full Disk Access to /Users/basnijholt/Library/Application Support/mautrix-imessage/mautrix-imessage in System Settings and allow Messages automation and Contacts access when prompted.
Messages must be signed in, and the Mac user must be logged in after a reboot.
Launchd retries failed starts; logs are launchagent.stdout.log and launchagent.stderr.log in the private directory.
The Mac connects outbound to wss://mindroom.chat/_matrix/client/unstable/fi.mau.as_sync, so no inbound port on the Mac is needed.
Once both services connect, message @imessagebot:mindroom.chat in Element with help.
