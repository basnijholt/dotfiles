let
  bas = (import ../../../common/ssh-keys.nix).userKeys.bas;
  momHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3t8iXHYZLXYs1I0Tk6hVi7fRP1xOwqxCnMNE3AeUHZ root@nixos";
  recipients = [ bas momHost ];
in
{
  "agent-runtime.env.age".publicKeys = recipients;
}
