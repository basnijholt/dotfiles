# VM-specific overrides for running HP config in Incus
# All differences from real HP hardware are centralized here
/*
=== Installation Instructions ===
1. Create empty VM on your PC (which has Incus enabled):

   incus create hp-incus --vm --empty \
     -c limits.memory=4GiB \
     -c limits.cpu=2 \
     -c security.secureboot=false \
     -d root,size=50GiB

2. Attach NixOS ISO and start with console:

   incus config device add hp-incus iso disk source=/path/to/nixos.iso boot.priority=1
   incus start hp-incus --console

3. Inside the ISO, partition with Disko and install:

   nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount \
     --flake github:basnijholt/dotfiles?dir=configs/nixos#hp-incus

   nixos-install --root /mnt --no-root-passwd \
     --flake github:basnijholt/dotfiles?dir=configs/nixos#hp-incus

4. Remove ISO and reboot:

   incus config device remove hp-incus iso
   incus restart hp-incus

5. Login with root/nixos, then change passwords.
*/

{ modulesPath, lib, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  networking.hostName = lib.mkForce "hp-incus";
  # Unique hostId for ZFS (different from real HP)
  networking.hostId = lib.mkForce "a7d4a137";

  # --- Disk: use virtio instead of NVMe ---
  disko.devices.disk.nvme.device = lib.mkForce "/dev/vda";

  # --- Boot: virtio-compatible ---
  boot.initrd.availableKernelModules = lib.mkForce [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];
  boot.loader.grub.device = lib.mkForce "/dev/vda";

  # --- Networking: simple DHCP, no bridging ---
  # Real HP needs bridging to host VMs; this VM just needs connectivity
  systemd.network.enable = lib.mkForce false;
  systemd.network.netdevs = lib.mkForce { };
  systemd.network.networks = lib.mkForce { };
  networking.useDHCP = lib.mkForce true;
  networking.firewall.trustedInterfaces = lib.mkForce [ ];

  # Easy login for testing
  users.users.root.password = "nixos";
}
