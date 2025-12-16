# Incus LXC Container with NixOS and Docker

This runs on my TrueNAS Scale server.

1. I just created a basic NixOS LXC container via the UI on http://truenas.local/ui/containers/new.
2. Then NIC -> Add -> `br0`.

From a webUI shell, I then do (note I replaced the nix-cache.local with the IP because of DNS issues):
```bash
nixos-rebuild switch \
  --flake "github:basnijholt/dotfiles/main?dir=configs/nixos#docker-lxc" \
  --option sandbox false \
  --option substituters "http://192.168.1.145:5000 https://cache.nixos.org https://nix-community.cachix.org https://cache.nixos-cuda.org" \
  --option trusted-public-keys "build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
```

From TrueNAS shell, I then do:
```bash
incus config device add nixos gpu gpu pci=0000:00:02.0
```