# SSH public keys for all machines
let
  userKeys = {
    bas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC90KqGLJG4vaYYes3dDwD46Ui3sDiExPTbL7AkYg7i9 bas@nijho.lt";
    blink = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMRmEP/ZUShYdZj/h3vghnuMNgtWExV+FEZHYyguMkX basnijholt@blink";
    iphone18 = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBB3wlyMCP3anu3qHd4cZUBZf+Nu3zoGYQ+t5ahQ1Br0lxJeUartMKiI1Ux+ctBtDim0+g+CMFCqgg71umFmZfrc= basnijholt@iphone18";
  };
in
{
  inherit userKeys;
  sshKeys = builtins.attrValues userKeys;
}
