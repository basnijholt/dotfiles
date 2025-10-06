{ ... }:

{
  # --- Hostname & Networking ---
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # --- Ensure WiFi stays up ---
  networking.networkmanager.settings."connection"."wifi.powersave" = 2;

  # NOTE: Kind’s pod network (10.244.0.0/16) changes host bridge names every time the
  #       cluster is rebuilt, so NixOS’ reverse-path filter would keep dropping pod→host
  #       packets unless we constantly refresh a matching route. Disabling the check
  #       here prevents rpfilter from black-holing inter-node traffic whenever kind
  #       recreates its Docker network.
  networking.firewall.checkReversePath = false;
  networking.firewall.allowedTCPPorts = [
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
}
