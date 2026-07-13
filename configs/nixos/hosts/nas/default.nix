{ lib, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    ../../optional/power.nix
    ../../optional/ups-client.nix
    ../../optional/zfs-sanoid.nix

    # Host-specific modules (Tier 3)
    ./health.nix
    ./identity.nix
    ./networking.nix
    ./storage.nix
    ./nfs.nix
    ./replication.nix
    ./samba.nix
    ./virtualization.nix
    ./zfs-unlock.nix
  ];

  # The live workload runs Syncthing in Docker, not as a host-level service.
  services.syncthing.enable = lib.mkForce false;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "fwupd-refresh" &&
        (
          action.id == "org.freedesktop.fwupd.get-remotes" ||
          action.id == "org.freedesktop.fwupd.refresh-remote"
        )
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  networking.hostId = "4ce3f761";
}
