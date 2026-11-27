{ config, pkgs, mindroom-sygnal, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) iosPushAppId androidPushAppId androidFcmProjectId;

  sygnalImage = "docker.io/matrixdotorg/sygnal@sha256:141f5e72fdf99a28e29ca87f3a46c19ed1cf21d5074aa3ef9df7c067e0c1c46a";
  mindroomSygnalPkg = mindroom-sygnal.packages.${pkgs.stdenv.hostPlatform.system}.default;

  sygnalConfigTemplate = pkgs.writeText "sygnal.yaml" ''
    log:
      setup:
        version: 1
        formatters:
          normal:
            format: "%(asctime)s [%(process)d] %(levelname)-5s %(name)s %(message)s"
        handlers:
          stderr:
            class: "logging.StreamHandler"
            formatter: "normal"
            stream: "ext://sys.stderr"
          stdout:
            class: "logging.StreamHandler"
            formatter: "normal"
            stream: "ext://sys.stdout"
        loggers:
          sygnal.access:
            propagate: false
            handlers: ["stdout"]
            level: "INFO"
          sygnal:
            propagate: false
            handlers: ["stderr"]
        root:
          handlers: ["stderr"]
          level: "INFO"
        disable_existing_loggers: false
      access:
        x_forwarded_for: true

    http:
      bind_addresses: ["0.0.0.0"]
      port: 5000

    metrics:
      prometheus:
        enabled: false
      opentracing:
        enabled: false
      sentry:
        enabled: false

    apps:
      ${iosPushAppId}:
        type: mindroom_pushkin_loader.SafeApnsPushkin
        keyfile: /sygnal/sygnal-apns-key.p8
        key_id: $SYGNAL_APNS_KEY_ID
        team_id: $SYGNAL_APNS_TEAM_ID
        topic: $SYGNAL_APNS_TOPIC
        platform: $SYGNAL_APNS_PLATFORM
        convert_device_token_to_hex: false
      ${androidPushAppId}:
        type: mindroom_pushkin_loader.SafeFcmPushkin
        api_version: v1
        project_id: ${androidFcmProjectId}
        service_account_file: /sygnal/sygnal-fcm-service-account.json
  '';

  sygnalRestartTriggers = [
    sygnalConfigTemplate
    mindroomSygnalPkg
    config.age.secrets.sygnal-env.file
    config.age.secrets.sygnal-apns-key.file
    config.age.secrets.sygnal-fcm-service-account.file
  ];
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  systemd.tmpfiles.rules = [
    "d /run/sygnal 0750 root root -"
  ];

  systemd.services.sygnal-setup = {
    description = "Prepare Sygnal runtime configuration";
    before = [ "podman-sygnal.service" ];

    restartTriggers = sygnalRestartTriggers;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      install -d -m 0750 /run/sygnal
      install -m 0400 ${config.age.secrets.sygnal-apns-key.path} /run/sygnal/sygnal-apns-key.p8
      install -m 0400 ${config.age.secrets.sygnal-fcm-service-account.path} /run/sygnal/sygnal-fcm-service-account.json
      install -m 0444 ${mindroomSygnalPkg}/mindroom_pushkin.py /run/sygnal/mindroom_pushkin.py
      install -m 0444 ${mindroomSygnalPkg}/mindroom_fcm_pushkin.py /run/sygnal/mindroom_fcm_pushkin.py
      install -m 0444 ${mindroomSygnalPkg}/mindroom_pushkin_loader.py /run/sygnal/mindroom_pushkin_loader.py
      set -a
      . ${config.age.secrets.sygnal-env.path}
      set +a
      ${pkgs.envsubst}/bin/envsubst \
        -o /run/sygnal/sygnal.yaml \
        -i ${sygnalConfigTemplate}
      chmod 0400 /run/sygnal/sygnal.yaml
    '';
  };

  virtualisation.oci-containers.containers.sygnal = {
    image = sygnalImage;
    autoStart = true;
    environment = {
      PYTHONUNBUFFERED = "1";
      PYTHONDONTWRITEBYTECODE = "1";
      PYTHONPATH = "/sygnal";
      SYGNAL_CONF = "/sygnal/sygnal.yaml";
    };
    ports = [ "127.0.0.1:5000:5000" ];
    volumes = [ "/run/sygnal:/sygnal:ro" ];
  };

  systemd.services.podman-sygnal = {
    after = [ "network-online.target" "sygnal-setup.service" ];
    requires = [ "sygnal-setup.service" ];
    wants = [ "network-online.target" ];
    restartTriggers = sygnalRestartTriggers;
    serviceConfig.ExecCondition = ''
      ${pkgs.bash}/bin/bash -lc '[ -s ${config.age.secrets.sygnal-apns-key.path} ] \
        && ! grep -q "CHANGE_ME" ${config.age.secrets.sygnal-apns-key.path} \
        && [ -s ${config.age.secrets.sygnal-fcm-service-account.path} ] \
        && ! grep -q "CHANGE_ME" ${config.age.secrets.sygnal-fcm-service-account.path} \
        && grep -q "^SYGNAL_APNS_KEY_ID=" ${config.age.secrets.sygnal-env.path} \
        && ! grep -q "CHANGE_ME" ${config.age.secrets.sygnal-env.path}'
    '';
  };

  environment.systemPackages = [ pkgs.podman ];
}
