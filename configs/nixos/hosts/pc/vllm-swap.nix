{ pkgs, ... }:

let
  vllmSwap = "/var/lib/vllm-swap/current/bin/vllm-swap";
  cleanupVllmSwap = pkgs.writeShellScript "cleanup-vllm-swap" ''
    if [[ -x ${vllmSwap} ]]; then
      exec ${vllmSwap} cleanup
    fi
  '';
in
{
  systemd.tmpfiles.rules = [ "d /var/lib/vllm-swap 0750 basnijholt users - -" ];

  systemd.services.llama-swap = {
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    path = [ pkgs.docker ];
    serviceConfig = {
      RuntimeDirectory = "llama-swap-vllm";
      RuntimeDirectoryMode = "0750";
      RuntimeDirectoryPreserve = "restart";
      ExecStopPost = cleanupVllmSwap;
      TimeoutStopSec = "240s";
    };
  };

  systemd.sockets.llama-swap-port-8010 = {
    description = "Compatibility listener for the former Club3090 vLLM endpoint";
    wantedBy = [ "multi-user.target" ];
    before = [
      "multi-user.target"
      "shutdown.target"
    ];
    conflicts = [ "shutdown.target" ];
    unitConfig.DefaultDependencies = false;
    listenStreams = [ "0.0.0.0:8010" ];
  };

  systemd.services.llama-swap-port-8010 = {
    description = "Proxy port 8010 to llama-swap";
    after = [ "llama-swap.service" ];
    requires = [ "llama-swap.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:9292";
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
