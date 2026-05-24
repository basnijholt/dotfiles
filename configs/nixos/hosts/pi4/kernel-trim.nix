# Keep the Raspberry Pi 4 kernel small enough to build locally while retaining ZFS.
{ lib, ... }:

{
  boot.kernelPatches = [
    {
      name = "pi4-trim-non-pi-modules";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        DRM = lib.mkForce no;
        DRM_AMDGPU = lib.mkForce no;
        DRM_RADEON = lib.mkForce no;
        DRM_NOUVEAU = lib.mkForce no;
        DRM_I915 = lib.mkForce no;
        DRM_XE = lib.mkForce no;
        DRM_AST = lib.mkForce no;
        DRM_MGAG200 = lib.mkForce no;
        DRM_QXL = lib.mkForce no;
        DRM_VIRTIO_GPU = lib.mkForce no;
        DRM_BOCHS = lib.mkForce no;

        FB_ATY = lib.mkForce no;
        FB_I740 = lib.mkForce no;
        FB_MATROX = lib.mkForce no;
        FB_NVIDIA = lib.mkForce no;
        FB_RADEON = lib.mkForce no;

        MEDIA_SUPPORT = lib.mkForce no;

        FIREWIRE = lib.mkForce no;
        PCMCIA = lib.mkForce no;
        PCCARD = lib.mkForce no;
        THUNDERBOLT = lib.mkForce no;

        SOUND = lib.mkForce no;
        SND = lib.mkForce no;
        SND_HDA_INTEL = lib.mkForce no;
        SND_HDSP = lib.mkForce no;
        SND_HDSPM = lib.mkForce no;
        SND_TRIDENT = lib.mkForce no;
        SND_VXPOCKET = lib.mkForce no;
        SND_SOC_AMD = lib.mkForce no;
        SND_SOC_INTEL = lib.mkForce no;

      };
    }
  ];
}
