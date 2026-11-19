# Nix

On a fresh macOS machine, install [Homebrew](https://brew.sh/) first and put it on PATH for the current shell:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Then install [Determinate Nix](https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#determinate-nix-installer) and open a new terminal:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

For the first switch, name this Mac's entry in `darwinConfigurations` in [`flake.nix`](flake.nix) explicitly, because the current hostname won't match yet.
Activation sets HostName, LocalHostName, and ComputerName to that name.

```bash
sudo nix run nix-darwin -- switch --flake ~/dotfiles/configs/nix-darwin#basnijholt-macbook-pro-m5
```

After that, `darwin-rebuild` finds the configuration by LocalHostName, so in a new terminal use the alias:

```bash
nixswitch
```

The always-on M2 imports imessage.nix to install a pinned official bridge and run it as a user LaunchAgent.
Its private config.yaml and database live in ~/Library/Application Support/mautrix-imessage/ and stay outside the Nix store.
This Mac's existing configuration targets @basnijholt:mindroom.chat and requires encrypted Matrix rooms.
Set bridge.login_shared_secret to appservice in the private config.yaml so messages sent from your Apple devices also appear as your Matrix user; the server registration allows only @basnijholt:mindroom.chat for this login.
On a replacement Mac, securely copy config.yaml to the same directory with mode 0600; its tokens must match configs/nixos/hosts/hetzner-matrix/secrets/imessage-appservice-env.age.

Apply the Mac configuration with sudo darwin-rebuild switch --flake "path:$HOME/dotfiles/configs/nix-darwin#basnijholt-macbook-pro-m2" and apply the server configuration under configs/nixos/hosts/hetzner-matrix too.
Grant Full Disk Access to /Users/basnijholt/Library/Application Support/mautrix-imessage/mautrix-imessage in System Settings and allow Messages automation and Contacts access when prompted.
Messages must be signed in, and the Mac user must be logged in after a reboot.
Launchd retries failed starts; logs are launchagent.stdout.log and launchagent.stderr.log in the private directory.
The Mac connects outbound to wss://mindroom.chat/_matrix/client/unstable/fi.mau.as_sync, so no inbound port on the Mac is needed.
Once both services connect, message @imessagebot:mindroom.chat in Element with help.
