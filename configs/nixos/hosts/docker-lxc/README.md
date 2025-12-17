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
# Required for Docker-in-LXC: nesting and privileged mode
incus config set docker security.nesting=true security.privileged=true

# Workaround for CVE-2025-52881: runc/AppArmor bug causes "open sysctl net.ipv4.ip_unprivileged_port_start: permission denied"
# See: https://github.com/opencontainers/runc/issues/4968
# This disables AppArmor for the container (acceptable for a Docker host container)
incus config set docker raw.lxc 'lxc.apparmor.profile=unconfined'

# Add required devices and mounts
incus config device add docker disk0 disk source=/mnt/ssd/docker/data path=/mnt/data recursive=true shift=true
incus config device add docker disk1 disk source=/mnt/ssd/docker/stacks path=/opt/stacks recursive=true shift=true
incus config device add docker disk2 disk source=/mnt/tank path=/mnt/tank recursive=true
incus config device add docker gpu gpu pci=0000:00:02.0
incus restart docker
```