# NVIDIA graphics configuration
{ config, lib, pkgs, ... }:

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
    Option "Coolbits" "28"
  '';
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    # TODO: remove with the patchelf overlay in package-overrides.nix.
    # patchelf 0.19.2 writes a segfaulting nvidia-smi from the builder's single
    # --interpreter/--set-rpath call; nixpkgs#576397 splits it. Pin 0.15.2
    # until then; this turns itself off with a warning once that lands.
    package =
      let
        nvidia = config.boot.kernelPackages.nvidiaPackages.latest;
        builder = builtins.readFile (pkgs.path + "/pkgs/os-specific/linux/nvidia-x11/builder.sh");
      in
      if lib.hasInfix "--set-rpath $out/lib:$libPath $bin/bin/$i" builder then
        nvidia.overrideAttrs (old: {
          nativeBuildInputs = [ pkgs.patchelf_0_15 ] ++ old.nativeBuildInputs;
        })
      else
        lib.warn "nixpkgs#576397 is in nixpkgs: remove the NVIDIA patchelf pin in hosts/pc/nvidia-graphics.nix" nvidia;
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
