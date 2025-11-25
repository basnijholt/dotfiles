{ ... }:

{
  # --- Audio ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # This provides PulseAudio compatibility
    jack.enable = true; # For compatibility with JACK applications
  };
}
