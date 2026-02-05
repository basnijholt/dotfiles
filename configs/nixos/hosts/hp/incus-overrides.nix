# VM-specific overrides for running HP config in Incus
# All differences from real HP hardware are centralized here
#
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
     --yes-wipe-all-disks \
     --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#hp-incus'

   nixos-install --root /mnt --no-root-passwd \
     --option substituters "http://nix-cache.local:5000 https://cache.nixos.org https://nix-community.cachix.org https://cache.nixos-cuda.org" \
     --option trusted-public-keys "build-vm-1:CQeZikX76TXVMm+EXHMIj26lmmLqfSxv8wxOkwqBb3g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" \
     --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#hp-incus'

   nixos-enter --root /mnt -c 'passwd basnijholt' # Set user password

6. Remove ISO and reboot (from your PC, not the VM):

   incus stop hp-incus --force
   incus config device remove hp-incus iso
   incus start hp-incus

7. SSH in and update to latest (if needed):

   incus list                # Get new IP
   ssh basnijholt@<IP>
   nixos-rebuild switch --flake 'github:basnijholt/dotfiles/hp?dir=configs/nixos#hp-incus'

8. Change passwords.
*/

{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
  ];

  networking.hostName = lib.mkForce "hp-incus";
  networking.hostId = lib.mkForce "a7d4a137";  # Unique hostId for ZFS

  # --- Incus Guest Support ---
  virtualisation.incus.agent.enable = true;

  # --- Hardware Overrides for VM ---
  # Incus exposes root disk as SCSI (sda), not NVMe
  disko.devices.disk.nvme.device = lib.mkForce "/dev/sda";
  # Force ZFS to look for pools in /dev directly (VMs don't always have stable by-id)
  boot.zfs.devNodes = "/dev";
  # Use virtio modules instead of physical hardware modules
  boot.initrd.availableKernelModules = lib.mkForce [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];
  # No Intel microcode updates needed in VM
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;
  # Console output for Incus VM (serial + VGA)
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" ];

  # Disable hardware-specific workaround for physical NIC
  systemd.services.e1000e-workaround.enable = false;

  # Use systemd-boot for VM reliability (GRUB has issues with virtio paths)
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # --- Networking Overrides for VM ---
  # Match any ethernet interface (VM doesn't have eno1)
  systemd.network.networks."30-eno1".matchConfig.Name = lib.mkForce "en* eth*";
  # No hardcoded MAC (real HP uses MAC for DHCP reservation)
  systemd.network.netdevs."20-br0".netdevConfig = lib.mkForce {
    Kind = "bridge";
    Name = "br0";
  };

  # --- Testing ---
  users.users.root.password = "nixos";
}
