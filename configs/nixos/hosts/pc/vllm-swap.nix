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
}
