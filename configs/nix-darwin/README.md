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
