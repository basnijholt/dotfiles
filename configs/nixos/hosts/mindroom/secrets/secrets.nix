let
  bas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt";
  mindroomHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjCiCdxVhS5Y2YYHrjM8cg0VUedOIMC4YUvmDfOiIDd root@nixos";
  recipients = [ bas mindroomHost ];
in
{
  "registration-token.age".publicKeys = recipients;
  "cloudflare-acme-env.age".publicKeys = recipients;
  "openclaw-runtime.env.age".publicKeys = recipients;
}
