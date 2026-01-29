# VM-specific overrides for running paul-wyse config in Incus/QEMU
# All differences from real Wyse 5070 hardware are centralized here
#
/*
=== Installation Instructions ===

1. Build the installer ISO (from configs/nixos directory):

   nix build .#nixosConfigurations.installer.config.system.build.isoImage
   cp result/iso/*.iso /tmp/nixos.iso  # Must copy out of read-only nix store

2. Create empty VM:

   # Using Incus:
   incus create paul-wyse-incus --vm --empty \
     -c limits.memory=4GiB \
     -c limits.cpu=2 \
     -c security.secureboot=false \
     -d root,size=32GiB

   # Or using QEMU directly:
   qemu-img create -f qcow2 /tmp/paul-wyse-test.qcow2 32G

3. Attach NixOS ISO and start:

   # Incus:
   incus config device add paul-wyse-incus iso disk source=/tmp/nixos.iso boot.priority=10
   incus start paul-wyse-incus

   # QEMU:
   qemu-system-x86_64 -enable-kvm -m 4G -smp 2 \
     -bios /usr/share/ovmf/OVMF.fd \
     -hda /tmp/paul-wyse-test.qcow2 \
     -cdrom /tmp/nixos.iso -boot d

4. SSH into the VM (your key is authorized in the ISO):

   incus list                # Find the VM's IP address
   ssh root@<IP>             # SSH in (no password needed)

5. Partition with Disko and install (use branch name, e.g., "paul-wyse-host" or "main"):

   nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount \
     --yes-wipe-all-disks \
     --flake 'github:basnijholt/dotfiles/paul-wyse-host?dir=configs/nixos#paul-wyse-incus'

   nixos-install --root /mnt --no-root-passwd \
     --flake 'github:basnijholt/dotfiles/paul-wyse-host?dir=configs/nixos#paul-wyse-incus'

   nixos-enter --root /mnt -c 'passwd basnijholt' # Set user password

6. Remove ISO and reboot:

   # Incus (from host):
   incus stop paul-wyse-incus --force
   incus config device remove paul-wyse-incus iso
   incus start paul-wyse-incus

   # QEMU: just reboot without -cdrom

7. Test services:

   # DNS should resolve *.local to 127.0.0.1
   dig media.local @localhost

   # After tailscale up, Caddy should proxy to home server
   curl -H "Host: media.local" http://localhost
*/

{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
  ];

  networking.hostName = lib.mkForce "paul-wyse-incus";

  # --- Incus/QEMU Guest Support ---
  virtualisation.incus.agent.enable = true;

  # --- Hardware Overrides for VM ---
  # VM exposes root disk as SCSI (sda), not eMMC (mmcblk0)
  disko.devices.disk.main.device = lib.mkForce "/dev/sda";
  # Force ZFS to look for pools in /dev directly (VMs don't have stable by-id)
  boot.zfs.devNodes = "/dev";
  # Use virtio modules instead of eMMC/physical hardware modules
  boot.initrd.availableKernelModules = lib.mkForce [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];
  # No Intel microcode updates needed in VM
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;
  # Console output for VM (serial + VGA)
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" ];

  # Use systemd-boot for VM reliability (GRUB has issues with virtio paths)
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # --- Networking Overrides for VM ---
  # Match any ethernet interface (VM doesn't have Realtek NIC)
  systemd.network.networks."30-lan".matchConfig.Name = lib.mkForce "en* eth*";
  # No hardcoded MAC needed
  systemd.network.netdevs."20-br0".netdevConfig = lib.mkForce {
    Kind = "bridge";
    Name = "br0";
  };

  # --- Testing ---
  users.users.root.password = "nixos";
}
