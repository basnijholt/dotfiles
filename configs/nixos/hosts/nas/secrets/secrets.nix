let
  bas = (import ../../../common/ssh-keys.nix).userKeys.bas;
  nasHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVVgr3VXPWMUMtvTatRBBmnvfMfAhBH9qvNjv0Kl7sD root@nas";
  recipients = [ bas nasHost ];
in
{
  "nas-health-alert.env.age".publicKeys = recipients;
}
