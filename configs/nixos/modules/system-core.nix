{ pkgs, ... }:

{
  # ===================================
  # System Configuration
  # ===================================
  # --- Core Settings ---
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- System Compatibility ---
  programs.nix-ld.enable = true; # Run non-nix executables (e.g., micromamba)

  # --- DNS Resolver Defaults ---
  services.resolved = {
    enable = true;
    domains = [ "~local" ]; # Route .local queries to our DNS
    extraConfig = ''
      DNS=192.168.1.4 100.100.100.100
    '';
  };

  # --- Audio ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # This provides PulseAudio compatibility
    jack.enable = true; # For compatibility with JACK applications
  };

  # --- Shell & Terminal ---
  programs.zsh.enable = true;
  programs.direnv.enable = true;

  # --- Fonts ---
  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    nerd-fonts.jetbrains-mono
  ];
}
