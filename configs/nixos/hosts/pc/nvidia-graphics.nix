# NVIDIA graphics configuration
{ config, pkgs, ... }:

let
  # --- NVIDIA Wayland VRAM Workaround (driver >= R565) ---
  # Fresh login -> Hyprland grabs ~3.2 GiB of GPU memory on a 5K screen.
  # Adding a profile targeting ".Hyprland-wrapped" caps the driver's free-buffer
  # pool -> usage drops to ~800 MiB.
  #
  # References:
  #   - https://github.com/NVIDIA/egl-wayland/issues/126#issuecomment-2379945259
  #   - https://github.com/hyprwm/Hyprland/issues/7704#issuecomment-2639212608
  limitFreeBufferProfile = builtins.toJSON {
    rules = [
      {
        pattern = { feature = "procname"; matches = ".Hyprland-wrapped"; };
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }
      {
        pattern = { feature = "procname"; matches = "gnome-shell"; };
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }
    ];
    profiles = [{
      name = "Limit Free Buffer Pool On Wayland Compositors";
      settings = [{ key = "GLVidHeapReuseRatio"; value = 0; }];
    }];
  };
in
{
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.deviceSection = ''
    Section "Device"
      Identifier "nvidia-undervolt"
      Driver "nvidia"
      Option "Coolbits" "28"
    EndSection
  '';
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

  # --- Wayland Environment ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";  # nixpkgs-wrapped Chromium/Electron apps
    ELECTRON_OZONE_PLATFORM_HINT = "auto";  # Flatpak/AppImage/binaries
  };

  # NVIDIA VRAM leak workaround (see comment at top)
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    limitFreeBufferProfile;
}
