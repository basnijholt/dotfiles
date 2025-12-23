# Hetzner Cloud boot configuration
#
# Hetzner x86_64 uses legacy BIOS boot, not UEFI.
# Disko handles GRUB device configuration via the BIOS boot partition.
{ ... }:

{
  # Use GRUB for legacy boot
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
    # Don't set device here - disko configures it via the bios partition
  };

  # Disable systemd-boot (conflicts with GRUB)
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
}
