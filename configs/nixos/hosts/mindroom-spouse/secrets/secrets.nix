let
  bas = (import ../../../common/ssh-keys.nix).userKeys.bas;
  spouseHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAuvyHXxEqBd/egwM5875RhWF1QekxZQWNO/BMn2wZqC root@nixos";
  recipients = [ bas spouseHost ];
in
{
  "openclaw-runtime.env.age".publicKeys = recipients;
}
