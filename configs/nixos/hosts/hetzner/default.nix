# Hetzner Cloud VPS - minimal Docker Compose host
#
# A lightweight host for running Docker Compose stacks (websites, services).
# Uses common packages but excludes optional/large-packages.nix.
{ lib, pkgs, ... }:

{
  imports = [
    # Optional modules
    ../../optional/zfs-sanoid.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  # Docker for compose stacks - enabled directly, not via virtualization.nix
  # (which also pulls in libvirt, incus, virt-manager)
  virtualisation.docker.enable = true;

  # Google Cloud SDK for deployments
  environment.systemPackages = with pkgs; [
    google-cloud-sdk
    lz4
    mbuffer
  ];

  # Disable services that aren't needed on a web host
  services.fwupd.enable = lib.mkForce false; # No firmware updates on VPS
  services.syncthing.enable = lib.mkForce false; # No file sync needed

  # Fix SSH hanging - disable reverse DNS lookup (override common/services.nix)
  services.openssh.settings.UseDns = lib.mkForce false;

  # Allow root SSH for the NAS ZFS pull replication.
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    # NAS pull key (rotated 2026-07-21 from the unrestricted TrueNAS-era
    # RSA key). Private half: /etc/ssh/nas-replication-hetzner-ed25519 on
    # the NAS. Pinned to the NAS's tailnet IP; the pull connects via
    # 100.64.0.32, so only the NAS can use this key.
    "from=\"100.64.0.1\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtU9lEnbLj47AtqXyQRFDwepZpoqUUFy6VkrepFfA7l nas-replication-hetzner"
  ];

  # Override local LAN DNS servers (not reachable from Hetzner)
  networking.nameservers = lib.mkForce [ "1.1.1.1" "8.8.8.8" "100.100.100.100" ];

  # Remove local network cache (not reachable from Hetzner)
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];

  # Limit build parallelism to prevent OOM on small VPS
  nix.settings.max-jobs = 1;
  nix.settings.cores = 1;

  # Zram swap - compressed RAM swap for builds (ZFS doesn't support swapfiles well)
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Use up to 50% of RAM for compressed swap
  };

  # Keep the generated zram instance untouched during switch-to-configuration.
  # This must be a drop-in: a concrete systemd-zram-setup@zram0.service would
  # shadow zram-generator's unit and boot without zram swap.
  # Do not use systemd.services."systemd-zram-setup@zram0" here: that creates
  # the concrete unit and can reproduce the no-ExecStart/OOM failure mode.
  systemd.units."systemd-zram-setup@zram0.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      X-RestartIfChanged=false
      X-StopIfChanged=false
    '';
  };

  # Required for ZFS
  networking.hostId = "027a1bbc";
  # ZFS 2.4.0 pin is in hardware-configuration.nix

  # Enable Tailscale for Headscale connection (manually configured)
  services.tailscale.enable = lib.mkForce true;
}
