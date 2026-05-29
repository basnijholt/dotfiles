{ config, pkgs, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) iosPushAppId;

  sygnalImage = "docker.io/matrixdotorg/sygnal@sha256:141f5e72fdf99a28e29ca87f3a46c19ed1cf21d5074aa3ef9df7c067e0c1c46a";

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
        type: apns
        keyfile: /sygnal/sygnal-apns-key.p8
        key_id: $SYGNAL_APNS_KEY_ID
        team_id: $SYGNAL_APNS_TEAM_ID
        topic: $SYGNAL_APNS_TOPIC
        platform: $SYGNAL_APNS_PLATFORM
        convert_device_token_to_hex: false
  '';
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

    restartTriggers = [
      sygnalConfigTemplate
      config.age.secrets.sygnal-env.path
      config.age.secrets.sygnal-apns-key.path
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      install -d -m 0750 /run/sygnal
      install -m 0400 ${config.age.secrets.sygnal-apns-key.path} /run/sygnal/sygnal-apns-key.p8
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
      SYGNAL_CONF = "/sygnal/sygnal.yaml";
    };
    ports = [ "127.0.0.1:5000:5000" ];
    volumes = [ "/run/sygnal:/sygnal:ro" ];
  };

  systemd.services.podman-sygnal = {
    after = [ "network-online.target" "sygnal-setup.service" ];
    requires = [ "sygnal-setup.service" ];
    wants = [ "network-online.target" ];
    serviceConfig.ExecCondition = ''
      ${pkgs.bash}/bin/bash -lc '[ -s ${config.age.secrets.sygnal-apns-key.path} ] \
        && ! grep -q "CHANGE_ME" ${config.age.secrets.sygnal-apns-key.path} \
        && grep -q "^SYGNAL_APNS_KEY_ID=" ${config.age.secrets.sygnal-env.path} \
        && ! grep -q "CHANGE_ME" ${config.age.secrets.sygnal-env.path}'
    '';
  };

  environment.systemPackages = [ pkgs.podman ];
}
