# VM-specific overrides for running PC config in Incus
# All differences from real PC hardware are centralized here
#
# The goal is to build/install a VM as close as possible to the real PC.
# GPU-dependent services (NVIDIA, CUDA, Ollama, llama-swap, Wyoming) will
# build and install but won't function at runtime without a real GPU.
#
/*
=== Installation Instructions ===

1. Build the installer ISO (from configs/nixos directory):

   nix build .#nixosConfigurations.installer.config.system.build.isoImage
   cp result/iso/*.iso /tmp/nixos.iso  # Must copy out of read-only nix store

2. Create empty VM on your PC (which has Incus enabled):

   incus create pc-incus --vm --empty \
     -c limits.memory=16GiB \
     -c limits.cpu=4 \
     -c security.secureboot=false \
     -d root,size=100GiB

3. Attach NixOS ISO and start:

   incus config device add pc-incus iso disk source=/tmp/nixos.iso boot.priority=10
   incus start pc-incus

4. SSH into the VM (your key is authorized in the ISO):

   incus list                # Find the VM's IP address
   ssh root@<IP>             # SSH in (no password needed)

5. Partition with Disko and install:

   nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount \
     --yes-wipe-all-disks \
     --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#pc-incus'

   nixos-install --root /mnt --no-root-passwd \
     --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#pc-incus'

   nixos-enter --root /mnt -c 'passwd basnijholt' # Set user password

6. Remove ISO and reboot (from your PC, not the VM):

   incus stop pc-incus --force
   incus config device remove pc-incus iso
   incus start pc-incus

7. SSH in and update to latest (if needed):

   incus list                # Get new IP
   ssh basnijholt@<IP>
   nixos-rebuild switch --flake 'github:basnijholt/dotfiles/main?dir=configs/nixos#pc-incus'

8. Change passwords.

=== Runtime Limitations ===

These services will be installed but won't function without a real GPU:
- NVIDIA drivers and nvidia-smi
- nvidia-container-toolkit
- Ollama with CUDA acceleration
- llama-swap with CUDA
- Wyoming Faster-Whisper with CUDA
- Wyoming Piper with CUDA
- Sunshine game streaming
- Steam (no GPU acceleration)

These hardware features are stubbed:
- Bluetooth and Xbox controller support (xpadneo)
- AMD CPU microcode updates
*/

{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
  ];

  networking.hostName = lib.mkForce "pc-incus";

  # --- Hardware Overrides for VM ---
  # Incus exposes root disk as SCSI (sda), not NVMe
  disko.devices.disk.nvme1.device = lib.mkForce "/dev/sda";

  # Use virtio modules instead of physical hardware modules
  boot.initrd.availableKernelModules = lib.mkForce [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];

  # No AMD microcode updates needed in VM
  hardware.cpu.amd.updateMicrocode = lib.mkForce false;

  # Console output for Incus VM (serial + VGA)
  boot.kernelParams = lib.mkForce [ "console=tty0" "console=ttyS0,115200" ];

  # --- Boot Loader Overrides ---
  # Real PC uses GRUB with /boot2. VM uses GRUB but with /boot (standard for simple VMs)
  boot.loader.grub.enable = lib.mkForce true;
  boot.loader.grub.device = lib.mkForce "nodev";
  boot.loader.grub.efiSupport = lib.mkForce true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  
  # Ensure GRUB and EFI system know about the new mount point
  boot.loader.efi.efiSysMountPoint = lib.mkForce "/boot";

  # Override disko to use /boot instead of /boot2 for EFI partition
  disko.devices.disk.nvme1.content.partitions.esp.content.mountpoint = lib.mkForce "/boot";

  # --- Networking Overrides for VM ---
  # Use generic interface for NAT (VM doesn't have wlp7s0)
  networking.nat.externalInterface = lib.mkForce "en*";

  # --- Hardware Feature Stubs ---
  # These build fine but won't work at runtime in a VM

  # Bluetooth/gaming controllers don't exist in VM
  # (services.blueman, hardware.bluetooth, hardware.xpadneo are fine to keep)

  # NVIDIA driver will build but nvidia-smi won't find a GPU
  # (hardware.nvidia, services.xserver.videoDrivers are fine to keep)

  # --- Testing ---
  users.users.root.password = "nixos";
}
