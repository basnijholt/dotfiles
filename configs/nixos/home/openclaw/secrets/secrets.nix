let
  bas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt";
  mindroomHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjCiCdxVhS5Y2YYHrjM8cg0VUedOIMC4YUvmDfOiIDd root@nixos";
  spouseHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAuvyHXxEqBd/egwM5875RhWF1QekxZQWNO/BMn2wZqC root@nixos";
  recipients = [ bas mindroomHost spouseHost ];
in
{
  "openclaw-integrations.env.age".publicKeys = recipients;
  "openclaw-tooling.env.age".publicKeys = recipients;
}
