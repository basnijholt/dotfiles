# club-3090 vLLM service for Qwen3.6-27B on 2x RTX 3090.
{ pkgs, ... }:

let
  club3090 = pkgs.fetchFromGitHub {
    owner = "noonghunna";
    repo = "club-3090";
    rev = "bef766d4ae2c5a03958c5da3d79bfa6a92ab01dd"; # v0.8.0
    hash = "sha256-7wxsByfT5J9a3Qvtm/KFQF5TUk0Gcm2MeEaAHJftQPk=";
  };

  defaultVllmImage = "vllm/vllm-openai:cu129-nightly";
  stateDir = "/var/lib/club-3090-vllm";
  modelDir = "${stateDir}/models";
  cacheDir = "${stateDir}/cache";
  modelSubdir = "qwen3.6-27b-autoround-int4";
  modelRepo = "Lorbus/Qwen3.6-27B-int4-AutoRound";
  containerName = "club-3090-vllm-qwen36";
  downloadContainerName = "${containerName}-download";

  patches = "${club3090}/models/qwen3.6-27b/vllm/patches";

  downloadModel = pkgs.writeShellScript "club-3090-vllm-download-model" ''
    set -euo pipefail

    if [ -f "${modelDir}/${modelSubdir}/config.json" ]; then
      exit 0
    fi

    mkdir -p "${modelDir}/${modelSubdir}"

    ${pkgs.docker}/bin/docker rm -f "${downloadContainerName}" >/dev/null 2>&1 || true

    ${pkgs.docker}/bin/docker run --rm \
      --name "${downloadContainerName}" \
      --env "HF_TOKEN=''${HF_TOKEN:-}" \
      --env "HUGGING_FACE_HUB_TOKEN=''${HF_TOKEN:-}" \
      --volume "${modelDir}:/models" \
      --entrypoint bash \
      "''${VLLM_IMAGE:-${defaultVllmImage}}" \
      -lc 'hf download "${modelRepo}" --local-dir "/models/${modelSubdir}"'
  '';

  startVllm = pkgs.writeShellScript "club-3090-vllm-start" ''
    set -euo pipefail

    mkdir -p \
      "${modelDir}" \
      "${cacheDir}/torch_compile" \
      "${cacheDir}/triton"

    ${pkgs.docker}/bin/docker rm -f "${containerName}" >/dev/null 2>&1 || true

    exec ${pkgs.docker}/bin/docker run --rm \
      --name "${containerName}" \
      --device nvidia.com/gpu=all \
      --ipc host \
      --shm-size 16g \
      --publish "0.0.0.0:8010:8000" \
      --env "NVIDIA_VISIBLE_DEVICES=all" \
      --env "HF_TOKEN=''${HF_TOKEN:-}" \
      --env "HUGGING_FACE_HUB_TOKEN=''${HF_TOKEN:-}" \
      --env "VLLM_WORKER_MULTIPROC_METHOD=spawn" \
      --env "NVLINK_MODE=''${NVLINK_MODE:-auto}" \
      --env "NCCL_CUMEM_ENABLE=0" \
      --env "NCCL_P2P_DISABLE=1" \
      --env "VLLM_NO_USAGE_STATS=1" \
      --env "VLLM_USE_FLASHINFER_SAMPLER=1" \
      --env "OMP_NUM_THREADS=1" \
      --env "PYTORCH_CUDA_ALLOC_CONF=''${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True,max_split_size_mb:512}" \
      --volume "${modelDir}:/root/.cache/huggingface" \
      --volume "${cacheDir}/torch_compile:/root/.cache/vllm/torch_compile_cache" \
      --volume "${cacheDir}/triton:/root/.triton/cache" \
      --volume "${patches}/vllm-marlin-pad/marlin.py:/usr/local/lib/python3.12/dist-packages/vllm/model_executor/kernels/linear/mixed_precision/marlin.py:ro" \
      --volume "${patches}/vllm-marlin-pad/MPLinearKernel.py:/usr/local/lib/python3.12/dist-packages/vllm/model_executor/kernels/linear/mixed_precision/MPLinearKernel.py:ro" \
      --volume "${patches}/vllm-pr35936-required-fallback/vllm/entrypoints/openai/chat_completion/serving.py:/etc/club3090/pr35936-chat-completion-serving.py:ro" \
      --volume "${patches}/vllm-pr35936-required-fallback/vllm/entrypoints/openai/engine/serving.py:/etc/club3090/pr35936-engine-serving.py:ro" \
      --volume "${patches}/vllm-pr35936-required-fallback/install.sh:/etc/club3090/install-pr35936.sh:ro" \
      --volume "${patches}/vllm-pr41800-truncate-prompt-tokens/install.sh:/etc/club3090/install-pr41800.sh:ro" \
      --volume "${patches}/froggeric-chat-template/chat_template.jinja:/etc/qwen-froggeric-chat-template.jinja:ro" \
      --volume "${club3090}/scripts/detect_nvlink.sh:/etc/club3090/detect_nvlink.sh:ro" \
      --entrypoint bash \
      "''${VLLM_IMAGE:-${defaultVllmImage}}" \
      -c '
        set -euo pipefail
        bash /etc/club3090/install-pr35936.sh
        bash /etc/club3090/install-pr41800.sh
        source /etc/club3090/detect_nvlink.sh
        if [ "''${_NVLINK_ENABLED:-0}" = "1" ]; then
          exec vllm serve "''${@}"
        else
          exec vllm serve --disable-custom-all-reduce "''${@}"
        fi
      ' -- \
      --model "/root/.cache/huggingface/${modelSubdir}" \
      --served-model-name "qwen3.6-27b-autoround" \
      --quantization auto_round \
      --dtype float16 \
      --tensor-parallel-size 2 \
      --pipeline-parallel-size 1 \
      --max-model-len 65536 \
      --gpu-memory-utilization 0.70 \
      --max-num-seqs 1 \
      --max-num-batched-tokens 4096 \
      --kv-cache-dtype fp8_e5m2 \
      --trust-remote-code \
      --chat-template /etc/qwen-froggeric-chat-template.jinja \
      --reasoning-parser qwen3 \
      --default-chat-template-kwargs '{"enable_thinking": false}' \
      --enable-auto-tool-choice \
      --tool-call-parser qwen3_coder \
      --enable-prefix-caching \
      --enable-chunked-prefill \
      --speculative-config '{"method":"mtp","num_speculative_tokens":3}' \
      --host 0.0.0.0 \
      --port 8000
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 8010 ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 basnijholt users - -"
    "d ${modelDir} 0755 basnijholt users - -"
    "d ${cacheDir} 0755 basnijholt users - -"
    "d ${cacheDir}/torch_compile 0755 basnijholt users - -"
    "d ${cacheDir}/triton 0755 basnijholt users - -"
    "f ${stateDir}/env 0600 root root - -"
  ];

  systemd.services.club-3090-vllm = {
    description = "club-3090 vLLM Qwen3.6-27B dual-3090 server";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "simple";
      User = "root";
      EnvironmentFile = "-${stateDir}/env";
      ExecStartPre = downloadModel;
      ExecStart = startVllm;
      ExecStop = "${pkgs.docker}/bin/docker rm -f ${containerName}";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = "2h";
    };
  };
}
