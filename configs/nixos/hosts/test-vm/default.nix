# Minimal test VM for debugging Incus boot issues
# Strips away all services to isolate boot problems
{ modulesPath, lib, pkgs, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Basic system
  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = "x86_64-linux";

  # Minimal bootloader
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # VM hardware
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "virtio_blk" "ahci" "sd_mod" ];
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" ];

  # Filesystems managed by disko.nix

  # Networking - simple DHCP
  networking.hostName = "test-vm";
  networking.useDHCP = true;

  # SSH access
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  # Root login
  users.users.root.password = "nixos";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxsAOar9Feh0fPkjtDeCZaFUPT6GiA3XAXnSvVVBfAS basnijholt@gmail.com"
  ];

  # Minimal packages
  environment.systemPackages = with pkgs; [ vim ];
}
