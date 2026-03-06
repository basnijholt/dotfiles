let
  bas = (import ../../../common/ssh-keys.nix).userKeys.bas;
  mindroomHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjCiCdxVhS5Y2YYHrjM8cg0VUedOIMC4YUvmDfOiIDd root@nixos";
  recipients = [ bas mindroomHost ];
in
{
  "registration-token.age".publicKeys = recipients;
  "cloudflare-acme-env.age".publicKeys = recipients;
  "agent-runtime.env.age".publicKeys = recipients;
}
