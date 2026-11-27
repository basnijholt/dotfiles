{ config, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) iosPushAppId androidPushAppId androidFcmProjectId;
in
{
  services.mindroom-sygnal = {
    enable = true;
    extraRestartTriggers = [
      config.age.secrets.sygnal-env.file
      config.age.secrets.sygnal-apns-key.file
      config.age.secrets.sygnal-fcm-service-account.file
    ];
    apns = {
      enable = true;
      appId = iosPushAppId;
      keyFile = config.age.secrets.sygnal-apns-key.path;
      envFile = config.age.secrets.sygnal-env.path;
    };
    fcm = {
      enable = true;
      appId = androidPushAppId;
      projectId = androidFcmProjectId;
      serviceAccountFile = config.age.secrets.sygnal-fcm-service-account.path;
    };
  };
}
