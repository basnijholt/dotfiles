{ pkgs, ... }:

{
  security.acme = {
    acceptTerms = true;
    defaults.email = "bas@nijho.lt";

    certs.bumper-t80 = {
      domain = "bumper.lab.nijho.lt";
      extraDomainNames = [
        "*.local.nijho.lt"
        "*.area.robotww.local.nijho.lt"
        "*.dc.robotww.local.nijho.lt"
        "*.robotww.local.nijho.lt"
        "*.dc-na.robotww.local.nijho.lt"
        "*.dc-as.robotww.local.nijho.lt"
        "*.dc-eu.robotww.local.nijho.lt"
        "*.dc.ww.local.nijho.lt"
        "*.dc-na.ww.local.nijho.lt"
        "*.ww.local.nijho.lt"
      ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      environmentFile = "/opt/stacks/traefik/.env";
      group = "docker";
      # Match both Ecovacs' MQTT endpoint and the certificate already proven with
      # this robot. The NixOS default is EC256.
      keyType = "rsa2048";

      # Bumper reads its certificate only at startup. Restart it after a successful
      # issuance or renewal, but leave initial host provisioning independent of the
      # Compose stack.
      postRun = ''
        if ${pkgs.docker}/bin/docker inspect bumper >/dev/null 2>&1; then
          ${pkgs.docker}/bin/docker restart bumper
        fi
      '';
    };
  };
}
