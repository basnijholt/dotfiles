let
  bas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt";
  hetznerMatrixHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMDyg4UMEpOKrNPDQV9iXB4Fnu583xb6MJpASHgfzHKM root@hetzner-bootstrap";
  recipients = [ bas hetznerMatrixHost ];
in
{
  "registration-token.age".publicKeys = recipients;
  "sso-google-secret.age".publicKeys = recipients;
  "sso-github-secret.age".publicKeys = recipients;
  "sso-apple-secret.age".publicKeys = recipients;
}
