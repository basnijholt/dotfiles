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

5. Partition with Disko and install (use branch name, e.g., "hp" or "main"):

   nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount \
     --flake 'github:basnijholt/dotfiles/hp?dir=configs/nixos#nuc-incus'

   nixos-install --root /mnt --no-root-passwd \
     --flake 'github:basnijholt/dotfiles/hp?dir=configs/nixos#nuc-incus'

6. Remove ISO and reboot:

   incus stop nuc-incus --force
   incus config device remove nuc-incus iso
   incus start nuc-incus

7. SSH in again and change passwords.
*/

{ modulesPath, lib, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  networking.hostName = lib.mkForce "nuc-incus";

  # --- Disk: Incus exposes root disk as SCSI (sda), not the real NVMe by-id ---
  disko.devices.disk.nvme.device = lib.mkForce "/dev/sda";

  # --- Boot: VM-compatible ---
  boot.initrd.availableKernelModules = lib.mkForce [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];
  boot.supportedFilesystems = [ "btrfs" ];
  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/sda";
      efiSupport = true;
    };
    efi.canTouchEfiVariables = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # --- Networking: simple DHCP, no bridging ---
  # Real NUC needs bridging to host VMs; this VM just needs connectivity
  systemd.network.enable = lib.mkForce false;
  systemd.network.netdevs = lib.mkForce { };
  systemd.network.networks = lib.mkForce { };
  networking.useDHCP = lib.mkForce true;
  networking.firewall.trustedInterfaces = lib.mkForce [ ];

  # Easy login for testing
  users.users.root.password = "nixos";
}
