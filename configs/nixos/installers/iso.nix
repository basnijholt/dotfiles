# Installer ISO configuration
# SSH is enabled with key-only auth; root login allowed but NO passwords.
{ pkgs, ... }:

{
  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  users.users.root = {
    initialPassword = "nixos"; # default console password
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt"
    ];
  };
}
