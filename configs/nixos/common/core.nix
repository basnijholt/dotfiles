# Core system settings shared by all hosts
{ pkgs, lib, options, ... }:

{
  # --- Core Settings ---
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- System Compatibility ---
  programs.nix-ld.enable = true; # Run non-nix executables (e.g., micromamba)
  programs.nix-ld.libraries = with pkgs; [
    portaudio # Required for agent-cli transcribe (sounddevice Python package)
  ];

  boot.kernel.sysctl = {
    "kernel.sysrq" = 1; # Enable Magic SysRq key for recovery

    # TCP buffer tuning for high-latency, high-bandwidth connections
    # Default 208KB is too small for transatlantic links (BDP at 300Mbps/263ms = 10MB)
    "net.core.rmem_max" = 33554432; # 32MB
    "net.core.wmem_max" = 33554432; # 32MB
    "net.ipv4.tcp_rmem" = "4096 131072 33554432"; # min default max
    "net.ipv4.tcp_wmem" = "4096 16384 33554432"; # min default max
  };

  # --- DNS Resolver Defaults ---
  # Primary: nuc (192.168.1.2), Secondary: hp (192.168.1.3), Fallback: Tailscale
  networking.nameservers = [ "192.168.1.2" "192.168.1.3" "100.100.100.100" ];
  services.resolved = {
    enable = true;
  } // lib.optionalAttrs (options.services.resolved ? settings) {
    # settings option only available in newer nixpkgs (not in nixos-raspberrypi's fork)
    settings.Resolve = {
      Domains = [ "~local" "~lab.nijho.lt" ]; # Route local zones to our DNS
      FallbackDNS = [ "1.1.1.1" "8.8.8.8" ]; # Public fallback when local resolvers fail
    };
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
    libertine # Linux Libertine fonts
  ];
}
