# Bas Nijholt's NixOS configs

- `modules/`: Shared modules every host imports by default (core system settings, shared packages, services, desktop profile).
- `hosts/pc/`: Desktop/workstation-specific modules (boot, disk layout, nixpkgs overlay, workstation packages, 1Password, GPU, AI extras, Slurm, etc.).
- `hosts/nuc/`: NUC-specific overrides (networking, Kodi packages, etc.).
- `disko/`: Disko layouts (PC currently consumes `hosts/pc/disko.nix`).
- `flake.nix`: Defines the `pc` and `nuc` NixOS configurations on top of shared modules.

## Host Roles

- **PC (`nixos` configuration)**: Full workstation with Docker/Incus, GPU, Hyprland desktop, dev toolchains, AI services. Only this host inherits the heavy packages/modules under `hosts/pc/`.
- **NUC (`nuc` configuration)**: Lightweight dev + media box. Shares basic packages and services but has its own networking tweaks and skips workstation-only modules.

## Workflow Notes

- Build the PC system: `nix build .#nixosConfigurations.nixos.config.system.build.toplevel`
- Build the NUC system (once its disk/boot modules exist): `nix build .#nixosConfigurations.nuc.config.system.build.toplevel`
- Host-specific overlays live under `hosts/<name>/` to keep shared modules tidy.
