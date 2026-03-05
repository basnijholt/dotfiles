{ lib, ... }:
let
  cloudflareAcmeSecretFile = ./secrets/cloudflare-acme-env.age;
in
{
  age.secrets =
    {
      registration-token = {
        file = ./secrets/registration-token.age;
        owner = "tuwunel";
        group = "tuwunel";
        mode = "0400";
      };
    }
    // lib.optionalAttrs (builtins.pathExists cloudflareAcmeSecretFile) {
      cloudflare-acme-env = {
        file = cloudflareAcmeSecretFile;
        owner = "acme";
        group = "acme";
        mode = "0400";
      };
    };
}
