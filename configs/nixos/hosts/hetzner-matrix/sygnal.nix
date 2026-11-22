{ config, lib, pkgs, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) iosPushAppId;

  sygnalImage = "docker.io/matrixdotorg/sygnal@sha256:141f5e72fdf99a28e29ca87f3a46c19ed1cf21d5074aa3ef9df7c067e0c1c46a";
  mindroomPushkin = ./mindroom_pushkin.py;

  # Construct the pushkin via Sygnal's real creation path offline. Exits 3 ONLY
  # on pushkin import/construction failure so sygnal-setup falls back to `apns`;
  # any other error (podman/storage/config) fails sygnal-setup for systemd retry.
  pushkinProbeCode = ''
    import asyncio, sys, traceback
    from twisted.internet.defer import ensureDeferred
    from twisted.internet.testing import MemoryReactorClock
    from sygnal.apnspushkin import ApnsPushkin
    from sygnal.sygnal import Sygnal, parse_config

    async def main():
        cfg = parse_config()
        s = Sygnal(cfg, MemoryReactorClock())
        for app_id, app_cfg in cfg["apps"].items():
            try:
                p = await ensureDeferred(s._make_pushkin(app_id, app_cfg)).asFuture(
                    asyncio.get_running_loop()
                )
                if not isinstance(p, ApnsPushkin):
                    raise TypeError(f"Expected ApnsPushkin, got {type(p)!r}")
            except Exception:
                traceback.print_exc()
                sys.exit(3)

    asyncio.run(main())
  '';

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
        type: $SYGNAL_APNS_TYPE
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
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "podman-sygnal.service" ];

    restartTriggers = [
      sygnalConfigTemplate
      mindroomPushkin
      config.age.secrets.sygnal-env.file
      config.age.secrets.sygnal-apns-key.file
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "15s";
    };

    script = ''
      install -d -m 0750 /run/sygnal
      install -m 0400 ${config.age.secrets.sygnal-apns-key.path} /run/sygnal/sygnal-apns-key.p8
      if [ -f ${mindroomPushkin} ]; then
        install -m 0444 ${mindroomPushkin} /run/sygnal/mindroom_pushkin.py
      else
        rm -f /run/sygnal/mindroom_pushkin.py
      fi
      set -a
      . ${config.age.secrets.sygnal-env.path}
      set +a
      export SYGNAL_APNS_TYPE="mindroom_pushkin.MindroomApnsPushkin"
      ${pkgs.envsubst}/bin/envsubst \
        -o /run/sygnal/sygnal.yaml.probe \
        -i ${sygnalConfigTemplate}
      chmod 0400 /run/sygnal/sygnal.yaml.probe
      rc=0
      ${pkgs.podman}/bin/podman run --rm --network=none --entrypoint python \
        -e PYTHONDONTWRITEBYTECODE=1 \
        -e PYTHONPATH=/sygnal \
        -e SYGNAL_CONF=/sygnal/sygnal.yaml.probe \
        -v /run/sygnal:/sygnal:ro \
        ${sygnalImage} \
        -c ${lib.escapeShellArg pushkinProbeCode} || rc=$?
      if [ "$rc" -eq 0 ]; then
        mv -f /run/sygnal/sygnal.yaml.probe /run/sygnal/sygnal.yaml
      elif [ "$rc" -eq 3 ]; then
        echo "WARNING: mindroom_pushkin failed preflight (exit 3); falling back to stock apns pushkin" >&2
        export SYGNAL_APNS_TYPE="apns"
        ${pkgs.envsubst}/bin/envsubst \
          -o /run/sygnal/sygnal.yaml.probe \
          -i ${sygnalConfigTemplate}
        chmod 0400 /run/sygnal/sygnal.yaml.probe
        mv -f /run/sygnal/sygnal.yaml.probe /run/sygnal/sygnal.yaml
      else
        rm -f /run/sygnal/sygnal.yaml.probe
        echo "ERROR: sygnal preflight failed with exit code $rc" >&2
        exit "$rc"
      fi
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
    restartTriggers = [
      sygnalConfigTemplate
      mindroomPushkin
    ];
    wants = [ "network-online.target" "sygnal-setup.service" ];
    serviceConfig.ExecCondition = ''
      ${pkgs.bash}/bin/bash -lc '[ -s ${config.age.secrets.sygnal-apns-key.path} ] \
        && ! grep -q "CHANGE_ME" ${config.age.secrets.sygnal-apns-key.path} \
        && grep -q "^SYGNAL_APNS_KEY_ID=" ${config.age.secrets.sygnal-env.path} \
        && ! grep -q "CHANGE_ME" ${config.age.secrets.sygnal-env.path}'
    '';
  };

  environment.systemPackages = [ pkgs.podman ];
}
