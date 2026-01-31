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

  # --- TCP Performance Tuning ---
  # BBR + large buffers: enables 300+ Mbps on high-latency links (vs ~8 Mbps with defaults)
  # Tested on Seattle <-> Germany (263ms RTT) - went from 2 Mbps to 300 Mbps
  #
  # For TrueNAS SCALE (which hosts docker-lxc), apply the same settings via CLI:
  #   ssh root@truenas.local
  #   midclt call tunable.create '{"var": "net.ipv4.tcp_congestion_control", "value": "bbr", "type": "SYSCTL", "enabled": true}'
  #   midclt call tunable.create '{"var": "net.core.default_qdisc", "value": "fq", "type": "SYSCTL", "enabled": true}'
  #   midclt call tunable.create '{"var": "net.core.rmem_max", "value": "67108864", "type": "SYSCTL", "enabled": true}'
  #   midclt call tunable.create '{"var": "net.core.wmem_max", "value": "67108864", "type": "SYSCTL", "enabled": true}'
  #   midclt call tunable.create '{"var": "net.ipv4.tcp_rmem", "value": "4096 131072 67108864", "type": "SYSCTL", "enabled": true}'
  #   midclt call tunable.create '{"var": "net.ipv4.tcp_wmem", "value": "4096 16384 67108864", "type": "SYSCTL", "enabled": true}'
  # These persist in TrueNAS UI under System Settings -> Advanced -> Sysctl

  boot.kernelModules = [ "tcp_bbr" ];

  # Don't prompt for ZFS encryption keys at boot
  # Our root datasets are unencrypted; only replicated backup datasets from TrueNAS are encrypted
  # Without this, replicated encrypted datasets block boot waiting for a passphrase
  boot.zfs.requestEncryptionCredentials = false;

  boot.kernel.sysctl = {
    "kernel.sysrq" = 1; # Enable Magic SysRq key for recovery

    # BBR congestion control - doesn't back off aggressively on loss like CUBIC
    "net.ipv4.tcp_congestion_control" = "bbr";

    # TCP buffer tuning for high-latency, high-bandwidth connections
    # Default 208KB is too small for transatlantic links (BDP at 300Mbps/263ms = 10MB)
    "net.core.rmem_max" = 67108864; # 64MB
    "net.core.wmem_max" = 67108864; # 64MB
    "net.ipv4.tcp_rmem" = "4096 131072 67108864"; # min default max
    "net.ipv4.tcp_wmem" = "4096 16384 67108864"; # min default max
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
