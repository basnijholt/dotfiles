{ lib, pkgs, ... }:

let
  # 270 W: Puget Systems + LocalLLaMA measurements show ~95% RTX 3090 perf
  # at a much lower wall draw, perfect for dual 3090 rigs.
  gpuPowerLimitW = 270;
  gpuIndices = [ 0 1 ];
  gpuList = lib.concatMapStringsSep " " toString gpuIndices;
  script = pkgs.writeShellScript "nv-power-limit" ''
    set -euo pipefail

    PATH=/run/opengl-driver/bin:/run/current-system/sw/bin:$PATH
    NV_SMI="$(command -v nvidia-smi || true)"
    if [ -z "$NV_SMI" ]; then
      NV_SMI="/run/opengl-driver/bin/nvidia-smi"
    fi

    if [ ! -x "$NV_SMI" ]; then
      echo "nvidia-smi not found" >&2
      exit 1
    fi

    if ! "$NV_SMI" --query-gpu=name >/dev/null 2>&1; then
      echo "nvidia-smi cannot talk to the driver yet (likely still switching); skipping until next boot" >&2
      exit 0
    fi

    "$NV_SMI" --persistence-mode=1
    for GPU in ${gpuList}; do
      "$NV_SMI" -i "$GPU" --power-limit=${toString gpuPowerLimitW}
    done
  '';
in
{
  systemd.services.nv-power-limit = {
    description = "Set NVIDIA GPU power limits on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = script;
    };
  };
}
