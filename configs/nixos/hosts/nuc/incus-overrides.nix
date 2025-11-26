# VM-specific overrides for running NUC config in Incus
# All differences from real NUC hardware are centralized here
/*
=== Installation Instructions ===

1. Build the installer ISO (from configs/nixos directory):

   nix build .#nixosConfigurations.installer.config.system.build.isoImage
   cp result/iso/*.iso /tmp/nixos.iso  # Must copy out of read-only nix store

2. Create empty VM on your PC (which has Incus enabled):

   incus create nuc-incus --vm --empty \
     -c limits.memory=8GiB \
     -c limits.cpu=2 \
     -c security.secureboot=false \
     -d root,size=50GiB

3. Attach NixOS ISO and start:

   incus config device add nuc-incus iso disk source=/tmp/nixos.iso boot.priority=10
   incus start nuc-incus

4. SSH into the VM (your key is authorized in the ISO):

   incus list                # Find the VM's IP address
   ssh root@<IP>             # SSH in (no password needed)

5. Partition with Disko and install (use branch name, e.g., "nuc" or "main"):

   nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount \
     --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#nuc-incus'

   nixos-install --root /mnt --no-root-passwd \
     --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#nuc-incus'

   nixos-enter --root /mnt -c 'passwd basnijholt' # Set user password

6. Remove ISO and reboot (from your PC, not the VM):

   incus stop nuc-incus --force
   incus config device remove nuc-incus iso
   incus start nuc-incus

7. SSH in and update to latest (if needed):

   incus list                # Get new IP
   ssh basnijholt@<IP>
   nixos-rebuild switch --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#nuc-incus'

8. Change passwords.
*/

{ modulesPath, lib, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
  ];

  networking.hostName = lib.mkForce "nuc-incus";

  # --- Hardware overrides for VM ---
  # Incus exposes root disk as SCSI (sda), not NVMe by-id
  disko.devices.disk.nvme.device = lib.mkForce "/dev/sda";
  # Use virtio modules instead of physical hardware modules
  boot.initrd.availableKernelModules = lib.mkForce [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];
  # No Intel microcode updates needed in VM
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;
  # Console output for Incus VM (serial + VGA)
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" ];

  # --- Networking: keep bridge setup, adapt for VM ---
  # Match any ethernet interface (VM doesn't have eno1)
  systemd.network.networks."30-eno1".matchConfig.Name = lib.mkForce "en*";
  # Override bridge config without hardcoded MAC (real NUC uses MAC for DHCP reservation)
  systemd.network.netdevs."20-br0".netdevConfig = lib.mkForce {
    Kind = "bridge";
    Name = "br0";
  };

  # Easy login for testing
  users.users.root.password = "nixos";
}
