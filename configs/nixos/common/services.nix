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
    # Sources of the NAS pull replication (PR #75): root@nas connects with
    # BatchMode=yes, which hard-fails on unknown host keys — the first pull
    # to each host died exactly that way. Keys read from each host's
    # /etc/ssh/ssh_host_ed25519_key.pub over authenticated SSH, 2026-07-24.
    # pc's survives reinstalls by design (host keys ride in the recovery
    # kit); a reinstalled hp/pi4/nuc must update its entry here.
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
