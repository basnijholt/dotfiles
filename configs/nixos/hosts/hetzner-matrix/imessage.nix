# Relay Matrix appservice transactions to the bridge on the always-on M2.
{ config, ... }:
{
  virtualisation.oci-containers.containers.mautrix-wsproxy = {
    # Official arm64 image, pinned independently of the moving latest tag.
    image = "dock.mau.dev/mautrix/wsproxy@sha256:76c812cbba79332f1d42682e9f76595381df217440a00522826b4c3f4c1f640f";
    autoStart = true;
    environment = {
      APPSERVICE_ID = "imessage";
      LISTEN_ADDRESS = "0.0.0.0:29331";
    };
    environmentFiles = [ config.age.secrets.imessage-appservice-env-wsproxy.path ];
    ports = [ "127.0.0.1:29331:29331" ];
  };
}
