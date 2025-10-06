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

  # Use systemd-resolved with local DNS server for .local domains
  networking.extraHosts = ''
    127.0.0.1 mindroom.lan api.mindroom.lan
    127.0.0.1 s1.mindroom.lan api.s1.mindroom.lan
    127.0.0.1 s2.mindroom.lan api.s2.mindroom.lan
    127.0.0.1 s3.mindroom.lan api.s3.mindroom.lan
    127.0.0.1 s4.mindroom.lan api.s4.mindroom.lan
    127.0.0.1 s5.mindroom.lan api.s5.mindroom.lan
  '';

  services.resolved = {
    enable = true;
    domains = [ "~local" ]; # Route .local queries to our DNS
    extraConfig = ''
      DNS=192.168.1.4 100.100.100.100
    '';
  };

  networking.firewall.checkReversePath = false;

  services.fstrim.enable = true;

  # --- NVIDIA Graphics ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
