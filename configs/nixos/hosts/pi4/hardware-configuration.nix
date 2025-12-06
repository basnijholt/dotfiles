# Raspberry Pi 4 hardware configuration
#
# Installation notes:
#   1. Build SD card image: nix build .#nixosConfigurations.pi4.config.system.build.sdImage
#   2. Flash to SD card: dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress
#   3. Boot the Pi and SSH in (user: basnijholt)
#   4. After first boot, run: nixos-generate-config --show-hardware-config
  # Update this file with actual UUIDs from generated config if needed
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  # Raspberry Pi 4 specific
  nixpkgs.hostPlatform = "aarch64-linux";

  # Boot configuration - RPi uses its own bootloader chain
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Kernel modules for RPi4
  boot.initrd.availableKernelModules = [ "usbhid" "usb_storage" "vc4" "pcie_brcmstb" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.supportedFilesystems = [ "zfs" ];

  # Required firmware for WiFi, Bluetooth, GPU
  hardware.enableRedistributableFirmware = true;

  # SD card / USB boot filesystem
  # The sd-image module handles this automatically for initial boot
  # After installation, you may want to set explicit UUIDs:
  # fileSystems."/" = {
  #   device = "/dev/disk/by-label/NIXOS_SD";
  #   fsType = "ext4";
  # };

  # Swap - recommended for RPi4's limited RAM (2-8GB)
  swapDevices = [
    { device = "/swapfile"; size = 2048; }
  ];

  # Power management optimizations for RPi4
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # Disable firmware updates (RPi firmware is handled differently)
  services.fwupd.enable = lib.mkForce false;

    # --- Firmware Population (The Nix Way) ---
    # Ensure /boot has the necessary RPi firmware and U-Boot to boot from SSD
    system.activationScripts.rpi-firmware = {
      text = ''
        echo "Populating /boot with RPi firmware..."
        target=/boot
        fw=${pkgs.raspberrypifw}/share/raspberrypi/boot
        uboot=${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin
  
        # Copy firmware files (update if newer)
        cp -u $fw/start*.elf $target/
        cp -u $fw/fixup*.dat $target/
        cp -u $fw/bootcode.bin $target/
        cp -u $fw/*.dtb $target/
        
        # Copy overlays
        mkdir -p $target/overlays
        cp -u $fw/overlays/*.dtbo $target/overlays/
        
        # Copy U-Boot
        cp -u $uboot $target/u-boot-rpi4.bin
  
        # Create basic config.txt if missing to load U-Boot
        if [ ! -f $target/config.txt ]; then
          cat > $target/config.txt <<EOF
        # NixOS Boot Configuration
        kernel=u-boot-rpi4.bin
        arm_64bit=1
        enable_uart=1
        EOF
        fi
      '';
      deps = [];
    };
  }
