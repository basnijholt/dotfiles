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

}
