{ ... }:

{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets.nas-health-alert-env = {
    file = ./secrets/nas-health-alert.env.age;
    path = "/etc/nas-health-alert.env";
    owner = "root";
    group = "root";
    mode = "0400";
  };
}
