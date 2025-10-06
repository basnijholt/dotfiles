{ pkgs, config, ... }:

{
  # ===================================
  # Boot Configuration
  # ===================================
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    useOSProber = true;
    device = "nodev";
    memtest86.enable = true;
    theme = pkgs.sleek-grub-theme.override {
      withStyle = "orange";
      withBanner = "Welcome Bas!";
    };
  };
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot2";
  };

  # ===================================
  # Hardware Configuration
  # ===================================
  # --- Swap ---
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];
}
