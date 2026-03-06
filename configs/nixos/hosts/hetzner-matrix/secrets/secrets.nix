let
  bas = (import ../../../common/ssh-keys.nix).userKeys.bas;
  hetznerMatrixHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMDyg4UMEpOKrNPDQV9iXB4Fnu583xb6MJpASHgfzHKM root@hetzner-bootstrap";
  recipients = [ bas hetznerMatrixHost ];
in
{
  "registration-token.age".publicKeys = recipients;
  "sso-google-secret.age".publicKeys = recipients;
  "sso-github-secret.age".publicKeys = recipients;
  "sso-apple-secret.age".publicKeys = recipients;
  "signal-appservice-env.age".publicKeys = recipients;
  "whatsapp-appservice-env.age".publicKeys = recipients;
  "telegram-appservice-env.age".publicKeys = recipients;
}
