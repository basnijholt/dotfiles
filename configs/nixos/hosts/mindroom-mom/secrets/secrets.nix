let
  bas = (import ../../../common/ssh-keys.nix).userKeys.bas;
  # TODO: after the mindroom-mom container first boots, add its host key
  # (ssh-keyscan or /etc/ssh/ssh_host_ed25519_key.pub) here and re-encrypt
  # with `ragenix --rules ./secrets.nix -r`.
  # momHost = "ssh-ed25519 AAAA... root@nixos";
  recipients = [ bas ];
in
{
  "agent-runtime.env.age".publicKeys = recipients;
}
