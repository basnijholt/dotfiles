# VM-specific overrides for running HP config in Incus
# All differences from real HP hardware are centralized here
/*
=== Installation Instructions ===

1. Build the installer ISO (from configs/nixos directory):

   nix build .#nixosConfigurations.installer.config.system.build.isoImage
   cp result/iso/*.iso /tmp/nixos.iso  # Must copy out of read-only nix store

2. Create empty VM on your PC (which has Incus enabled):

   incus create hp-incus --vm --empty \
     -c limits.memory=8GiB \
     -c limits.cpu=2 \
     -c security.secureboot=false \
     -d root,size=50GiB

3. Attach NixOS ISO and start:

   incus config device add hp-incus iso disk source=/tmp/nixos.iso boot.priority=10
   incus start hp-incus

4. SSH into the VM (your key is authorized in the ISO):

   incus list                # Find the VM's IP address
   ssh root@<IP>             # SSH in (no password needed)

5. Partition with Disko and install (use branch name, e.g., "hp" or "main"):

   nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount \
     --flake 'github:basnijholt/dotfiles/hp?dir=configs/nixos#hp-incus'

   nixos-install --root /mnt --no-root-passwd \
     --flake 'github:basnijholt/dotfiles/hp?dir=configs/nixos#hp-incus'

6. Remove ISO and reboot:

   incus stop hp-incus --force
   incus config device remove hp-incus iso
   incus start hp-incus

7. SSH in again and change passwords.
*/

{ modulesPath, lib, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  networking.hostName = lib.mkForce "hp-incus";
  # Unique hostId for ZFS (different from real HP)
  networking.hostId = lib.mkForce "a7d4a137";

  # --- Disk: Incus exposes root disk as SCSI (sda), not virtio (vda) ---
  disko.devices.disk.nvme.device = lib.mkForce "/dev/sda";

  # --- Boot: VM-compatible (EFI mode, same as real HP) ---
  boot.initrd.availableKernelModules = lib.mkForce [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];
  boot.supportedFilesystems = [ "zfs" ];
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";  # EFI mode
      efiSupport = true;
      copyKernels = true;  # Required for ZFS
    };
    efi.canTouchEfiVariables = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # --- Networking: keep bridge setup, adapt for VM ---
  # Match any ethernet interface (VM doesn't have eno1)
  systemd.network.networks."30-eno1".matchConfig.Name = lib.mkForce "en*";
  # Override bridge config without hardcoded MAC (real HP uses MAC for DHCP reservation)
  systemd.network.netdevs."20-br0".netdevConfig = lib.mkForce {
    Kind = "bridge";
    Name = "br0";
  };

  # Easy login for testing
  users.users.root.password = "nixos";
}
