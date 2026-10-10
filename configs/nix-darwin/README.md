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

## iMessage bridge on the always-on M2

`imessage.nix` installs a pinned official `mautrix-imessage` binary and runs it as a user LaunchAgent.
Only `basnijholt-macbook-pro-m2` enables it, for `@basnijholt:mindroom.chat`.
Non-secret settings live in `flake.nix`; the private configuration and database remain in `~/Library/Application Support/mautrix-imessage/`.
Activation preserves this stable executable path so macOS permissions do not depend on a changing Nix store path.

The current Mac already has `config.yaml` and generated `registration.yaml`.
Do not commit these files or put their tokens in Nix settings.
On a replacement Mac, securely copy the private configuration to the same directory (mode `0600`) before starting the agent.
Keep its tokens consistent with the server's encrypted `configs/nixos/hosts/hetzner-matrix/secrets/imessage-appservice-env.age`.
Regenerating the registration rotates the tokens and requires updating that secret.

Apply the Mac configuration with:

```bash
sudo darwin-rebuild switch --flake "path:$HOME/dotfiles/configs/nix-darwin#basnijholt-macbook-pro-m2"
```

In System Settings > Privacy & Security > Full Disk Access, add:

```text
/Users/basnijholt/Library/Application Support/mautrix-imessage/mautrix-imessage
```

The agent waits for Full Disk Access.
Allow Messages automation and Contacts access when macOS prompts.
Messages must be signed in, and the Mac user must be logged in after a reboot.
The agent's logs are `launchagent.stdout.log` and `launchagent.stderr.log` in the private directory.

The server-side `imessage.nix`, Tuwunel appservice entry, and Caddy websocket route are under `configs/nixos/hosts/hetzner-matrix`.
Apply that server configuration too: the Mac connects to `wss://mindroom.chat/_matrix/client/unstable/fi.mau.as_sync`, and Tuwunel delivers transactions to the server's loopback-only websocket proxy.
No inbound port on the Mac is needed.
Once both services connect, DM `@imessagebot:mindroom.chat` in Element and send `help`.
