let
  bas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt";
  spouseHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAuvyHXxEqBd/egwM5875RhWF1QekxZQWNO/BMn2wZqC root@nixos";
  recipients = [ bas spouseHost ];
in
{
  "openclaw-runtime.env.age".publicKeys = recipients;
}
