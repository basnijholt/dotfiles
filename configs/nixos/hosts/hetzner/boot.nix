# Hetzner Cloud boot configuration
#
# Hetzner x86_64 uses legacy BIOS boot, not UEFI.
# GRUB is required for MBR/legacy boot.
{ ... }:

{
  # Use GRUB for legacy boot (Hetzner x86_64 requirement)
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda"; # Install GRUB to MBR
    efiSupport = false; # No EFI on Hetzner x86_64
  };

  # Disable systemd-boot (conflicts with GRUB)
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
}
