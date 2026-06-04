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
  idleTimeoutSeconds = 30 * 60;

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

  idleCheck = pkgs.writeShellScript "club-3090-vllm-idle-check" ''
    set -euo pipefail

    env_file="${stateDir}/env"
    if [ -r "$env_file" ]; then
      # shellcheck disable=SC1090
      source "$env_file"
    fi

    idle_timeout="''${CLUB3090_VLLM_IDLE_TIMEOUT_SECONDS:-${toString idleTimeoutSeconds}}"
    last_active_file="${stateDir}/last-active"
    fingerprint_file="${stateDir}/last-fingerprint"

    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet club-3090-vllm.service; then
      echo "club-3090-vllm is not active; nothing to unload"
      exit 0
    fi

    now="$(${pkgs.coreutils}/bin/date +%s)"
    metrics="$(${pkgs.curl}/bin/curl -fsS --max-time 5 http://127.0.0.1:8010/metrics 2>/dev/null || true)"

    # During cold start the HTTP port may accept connections before /metrics is
    # useful. Treat that as active so the timer cannot kill a slow warmup.
    if [ -z "$metrics" ]; then
      printf '%s\n' "$now" > "$last_active_file"
      echo "metrics unavailable; treating service as active"
      exit 0
    fi

    active_requests="$(
      printf '%s\n' "$metrics" | ${pkgs.gawk}/bin/awk '
        /^vllm:num_requests_running\{/ { total += $2 }
        /^vllm:num_requests_waiting\{/ { total += $2 }
        END { print total + 0 }
      '
    )"

    activity_fingerprint="$(
      printf '%s\n' "$metrics" | ${pkgs.gawk}/bin/awk '
        /^vllm:prompt_tokens_total\{/ { total += $2 }
        /^vllm:generation_tokens_total\{/ { total += $2 }
        /^http_requests_total\{.*handler="\/v1\/chat\/completions"/ { total += $2 }
        END { printf "%.0f\n", total }
      '
    )"

    previous_fingerprint=""
    if [ -f "$fingerprint_file" ]; then
      previous_fingerprint="$(cat "$fingerprint_file")"
    fi

    if [ "$active_requests" != "0" ] || [ "$activity_fingerprint" != "$previous_fingerprint" ]; then
      printf '%s\n' "$now" > "$last_active_file"
      printf '%s\n' "$activity_fingerprint" > "$fingerprint_file"
      echo "activity detected: active_requests=$active_requests fingerprint=$activity_fingerprint"
      exit 0
    fi

    if [ ! -f "$last_active_file" ]; then
      printf '%s\n' "$now" > "$last_active_file"
      echo "initialized idle timer"
      exit 0
    fi

    last_active="$(cat "$last_active_file")"
    idle_for="$((now - last_active))"
    if [ "$idle_for" -ge "$idle_timeout" ]; then
      echo "idle for ''${idle_for}s >= ''${idle_timeout}s; stopping club-3090-vllm"
      ${pkgs.systemd}/bin/systemctl stop club-3090-vllm.service
    else
      echo "idle for ''${idle_for}s < ''${idle_timeout}s; keeping club-3090-vllm running"
    fi
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
    "f ${stateDir}/last-active 0644 root root - -"
    "f ${stateDir}/last-fingerprint 0644 root root - -"
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
      RestartPreventExitStatus = "137 143";
      RestartSec = 10;
      SuccessExitStatus = "137 143";
      TimeoutStartSec = "2h";
    };
  };

  systemd.services.club-3090-vllm-idle-check = {
    description = "Stop club-3090 vLLM after idle timeout";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = idleCheck;
    };
  };

  systemd.timers.club-3090-vllm-idle-check = {
    description = "Periodic club-3090 vLLM idle check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1min";
      AccuracySec = "15s";
      Unit = "club-3090-vllm-idle-check.service";
    };
  };
}
