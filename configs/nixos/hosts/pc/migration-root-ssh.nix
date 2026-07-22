# TEMPORARY: key-only root SSH for the btrfs -> ZFS migration (PR #16).
#
# nixos-anywhere needs root on the running system for its kexec handoff;
# common/services.nix sets PermitRootLogin = "no" fleet-wide. Same pattern
# as hosts/nuc/networking.nix.
#
# REVERT after the migration: delete this file and its import in default.nix.
{ lib, ... }:

let
  sshKeys = (import ../../common/ssh-keys.nix).sshKeys;
in
{
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = sshKeys;
}
