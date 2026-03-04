{ config, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) siteDomain cinnyDomain;
in
{
  services.git-repo-checkouts.repositories.mindroom = {
    path = "/srv/mindroom";
    url = "https://github.com/mindroom-ai/mindroom.git";
    branch = "main";
    user = "root";
    group = "root";
    updateWhenClean = true;
  };

  services.mindroom-local-provisioning = {
    enable = true;
    repoPath = "/srv/mindroom";
    matrixHomeserver = "https://${siteDomain}";
    matrixServerName = siteDomain;
    matrixRegistrationTokenFile = config.age.secrets.registration-token-provisioning.path;
    listenHost = "127.0.0.1";
    listenPort = 8776;
    corsOrigins = [ "https://${cinnyDomain}" ];
  };

  # Ensure provisioning code checkout exists before provisioning service starts.
  systemd.services.mindroom-local-provisioning = {
    after = [ "git-checkout-mindroom.service" ];
    wants = [ "git-checkout-mindroom.service" ];
  };
}
