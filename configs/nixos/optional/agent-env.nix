{
  config,
  ...
}:
let
  hostSecretsDir = ../hosts/${config.networking.hostName}/secrets;
  sharedSecretsDir = ../common/agent-env/secrets;
in
{
  # Match the existing host-secret pattern: decrypt at activation with the
  # machine SSH host key, while keeping shared agent env files outside any
  # single runtime module.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets.agent-runtime-env = {
    file = hostSecretsDir + "/agent-runtime.env.age";
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };

  age.secrets.agent-integrations-env = {
    file = sharedSecretsDir + "/agent-integrations.env.age";
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };

  age.secrets.agent-tooling-env = {
    file = sharedSecretsDir + "/agent-tooling.env.age";
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };
}
