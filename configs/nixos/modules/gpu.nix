{ pkgs, config, ... }:

{
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
