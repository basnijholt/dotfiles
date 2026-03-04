{ ... }:

{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets = {
    registration-token = {
      file = ./secrets/registration-token.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    registration-token-provisioning = {
      file = ./secrets/registration-token.age;
      owner = "mindroom-local-provisioning";
      group = "mindroom-local-provisioning";
      mode = "0400";
    };
    sso-google-secret = {
      file = ./secrets/sso-google-secret.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    sso-github-secret = {
      file = ./secrets/sso-github-secret.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    sso-apple-secret = {
      file = ./secrets/sso-apple-secret.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    signal-appservice-env-tuwunel = {
      file = ./secrets/signal-appservice-env.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    signal-appservice-env-mautrix = {
      file = ./secrets/signal-appservice-env.age;
      owner = "mautrix-signal";
      group = "mautrix-signal";
      mode = "0400";
    };
    whatsapp-appservice-env-tuwunel = {
      file = ./secrets/whatsapp-appservice-env.age;
      owner = "tuwunel";
      group = "tuwunel";
      mode = "0400";
    };
    whatsapp-appservice-env-mautrix = {
      file = ./secrets/whatsapp-appservice-env.age;
      owner = "mautrix-whatsapp";
      group = "mautrix-whatsapp";
      mode = "0400";
    };
  };
}
