# System services shared by all hosts
{ pkgs, ... }:

{
  services.fwupd.enable = true;
  services.syncthing.enable = true;
  services.tailscale.enable = true;

  # --- System Stability ---
  services.earlyoom = {
    enable = true;
    freeSwapThreshold = 10;
    freeMemThreshold = 10;
  };

  # --- SSH ---
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      UseDns = false;
      X11Forwarding = true;
    };
  };

  # --- Mosh ---
  programs.mosh.enable = true;

  # --- Security & Authentication ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # pinentryPackage is set in optional/desktop.nix (requires GUI)
  };

  # --- Known Hosts ---
  programs.ssh.knownHosts = {
    "nas" = {
      hostNames = [
        "nas"
        "nas.local"
        "truenas.local"
        "192.168.1.4"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVVgr3VXPWMUMtvTatRBBmnvfMfAhBH9qvNjv0Kl7sD";
    };
    # Pull replication connects as root@nas with BatchMode=yes, which
    # hard-fails on unknown host keys, so every source must be pinned here.
    # pc's key survives reinstalls (it rides in the recovery kit); a
    # reinstalled nuc/hp/pi4 must update its entry.
    "pc" = {
      hostNames = [ "pc" "192.168.1.5" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjiKKO6ajlHe5oZa9fGI1v9yLvjvuBH3ZZlYlCIlREt";
    };
    "nuc" = {
      hostNames = [ "nuc" "192.168.1.2" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRL54JIesy0f1FtG81ABXq/xbNNyUFXTA5qZWNoW097";
    };
    "hp" = {
      hostNames = [ "hp" "192.168.1.3" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5ZinYz3ul3fbg/+eA95t0dq0yBQw4UxBMyFKUihSTQ";
    };
    "pi4" = {
      hostNames = [ "pi4" "192.168.1.7" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJO+VhVe+mC9mQa0dyOT6fPmIxkTHeM5X0IdcpF4mGY";
    };
  };
}
