{ lib, config, ... }:

let
  isPc = config.networking.hostName == "nixos";
in
  {
    networking.hostName = lib.mkDefault "nixos";

    # --- NetworkManager is useful on all machines ---
    networking.networkmanager.enable = true;

    networking.networkmanager.settings."connection"."wifi.powersave" = 2;

    # Shared DNS resolver defaults; individual hosts can extend or override.
    services.resolved = {
      enable = true;
      domains = [ "~local" ];
    };
  }
  // lib.mkIf isPc {
    networking.extraHosts = ''
      127.0.0.1 mindroom.lan api.mindroom.lan
      127.0.0.1 s1.mindroom.lan api.s1.mindroom.lan
      127.0.0.1 s2.mindroom.lan api.s2.mindroom.lan
      127.0.0.1 s3.mindroom.lan api.s3.mindroom.lan
      127.0.0.1 s4.mindroom.lan api.s4.mindroom.lan
      127.0.0.1 s5.mindroom.lan api.s5.mindroom.lan
    '';

    services.resolved.extraConfig = ''
      DNS=192.168.1.4 100.100.100.100
    '';

    networking.firewall = {
      checkReversePath = false;
      allowedTCPPorts = [
        10200 # Wyoming Piper
        10300 # Wyoming Faster Whisper - English
        10301 # Wyoming Faster Whisper - Dutch
        10400 # Wyoming OpenWakeword
        8880 # Kokoro TTS
        6333 # Qdrant
        61337 # Agent CLI server
        8008 # Synapse
        8009 # Synapse
        8448 # Synapse
        9292 # llama-swap proxy
        8080 # element
        30080 # mindroom ingress http (kind)
        30443 # mindroom ingress https (kind)
      ];
    };
  };
