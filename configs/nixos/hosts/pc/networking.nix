# Network configuration for PC workstation
{ lib, ... }:

{
  networking.hostName = lib.mkDefault "pc";
  networking.hostId = "8425e349"; # Required for ZFS
  networking.networkmanager = {
    enable = true;
    # Leave Wi-Fi under NetworkManager, but let networkd own the wired bridge.
    unmanaged = [ "interface-name:enp5s0" "interface-name:br0" ];
    settings."connection"."wifi.powersave" = 2;
  };
  networking.useDHCP = false;
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # --- Bridge Netfilter Fix ---
  # Docker loads br_netfilter which causes bridged frames (including Incus
  # container traffic) to traverse iptables/nftables chains. This breaks
  # Incus container -> Docker-published-port connectivity (e.g., Whisper).
  boot.kernel.sysctl."net.bridge.bridge-nf-call-iptables" = 0;
  boot.kernel.sysctl."net.bridge.bridge-nf-call-ip6tables" = 0;

  systemd.network.enable = true;

  # --- Wired LAN Bridge ---
  # Put Incus containers directly on the LAN without macvlan's host reachability
  # limitation. Reuse the physical NIC's MAC so the router keeps the same lease.
  systemd.network.netdevs."20-br0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
      MACAddress = "24:4b:fe:48:60:2a";
    };
  };

  systemd.network.networks."30-enp5s0" = {
    matchConfig.Name = "enp5s0";
    networkConfig.Bridge = "br0";
    linkConfig.RequiredForOnline = "no";
  };

  systemd.network.networks."40-br0" = {
    matchConfig.Name = "br0";
    networkConfig.DHCP = "yes";
    linkConfig.RequiredForOnline = "no";
    dhcpV4Config.RouteMetric = 100;
    ipv6AcceptRAConfig.RouteMetric = 100;
    routes = [
      {
        Destination = "192.168.1.4/32";
        Scope = "link";
        PreferredSource = "192.168.1.5";
        Metric = 50;
      }
    ];
  };

  # --- Local DNS Overrides ---
  networking.extraHosts = ''
    127.0.0.1 mindroom.lan api.mindroom.lan
    127.0.0.1 s1.mindroom.lan api.s1.mindroom.lan
    127.0.0.1 s2.mindroom.lan api.s2.mindroom.lan
    127.0.0.1 s3.mindroom.lan api.s3.mindroom.lan
    127.0.0.1 s4.mindroom.lan api.s4.mindroom.lan
    127.0.0.1 s5.mindroom.lan api.s5.mindroom.lan
  '';

  # --- Firewall Configuration ---
  # NOTE: Kind's pod network (10.244.0.0/16) changes host bridge names every time
  # the cluster is rebuilt, so NixOS' reverse-path filter would keep dropping
  # pod->host packets unless we constantly refresh a matching route. Disabling
  # the check here prevents rpfilter from black-holing inter-node traffic
  # whenever kind recreates its Docker network.
  networking.firewall.checkReversePath = false;
  networking.firewall.trustedInterfaces = [ "br0" "incusbr0" "tailscale0" ];
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
    8443 # Incus
    8188 # ComfyUI
    9292 # llama-swap proxy
    9898 # asr_custom_model = "nvidia/canary-qwen-2.5b"
    11434 # ollama
    8080 # element
    8765 # MindRoom backend API
    3003 # MindRoom frontend dev
    30080 # mindroom ingress http (kind)
    30443 # mindroom ingress https (kind)
  ];

  # --- NAT for Incus Containers ---
  networking.nat = {
    enable = true;
    externalInterface = "br0";
    internalInterfaces = [ "incusbr0" ];
    forwardPorts = [
      { sourcePort = 8123; destination = "10.5.28.161:8123"; proto = "tcp"; }
    ];
  };
}
