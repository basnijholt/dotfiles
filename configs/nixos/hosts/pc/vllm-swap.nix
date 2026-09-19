{
  config,
  lib,
  pkgs,
  ...
}:

let
  cf = "/home/basnijholt/.local/bin/cf";
  modelRoot = "/var/lib/club-3090-vllm/models";
  normalModel = "${modelRoot}/qwen3.8-27b-autoround-int4";
  uncensoredModel = "${modelRoot}/qwen3.8-27b-huihui-autoround";
  draftModel = "${modelRoot}/qwen3.8-27b-dflash2-w4a16";

  club3090 = pkgs.fetchFromGitHub {
    owner = "noonghunna";
    repo = "club-3090";
    rev = "9abbf961602e6a0bd4920d606f78a6b99826e195";
    hash = "sha256-ivfR5eWeVVGU4uXz6J5uppyL2ioCe6ooIfOHMqSzQqc=";
  };

  embeddingPatch = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/syv-ai/HyperQwen/c0c81bbbbf91f11b54af7b95f49bd6d1570c2ba0/patches/qwen3_5-embed-quant.patch";
    hash = "sha256-he9AicCc1HjkT8lhdd6OaczR4W+o7olZQqTYpBN9Uf0=";
  };

  launcher = pkgs.writeScriptBin "vllm-swap" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ../../scripts/ai/vllm-swap.py}
  '';

  composeFormat = pkgs.formats.yaml { };
  jsonFormat = pkgs.formats.json { };

  mkCompose =
    {
      suffix,
      targetModel,
      servedModelName,
      quantization,
      patchEmbedding,
      fallbackPort,
    }:
    let
      project = "llama-swap-qwen38-${suffix}";
      container = project;
      volumes = [
        "${targetModel}:/models/target:ro"
        "${draftModel}:/models/draft:ro"
        "${club3090}/models/qwen3.8-27b/vllm/patches/fa2-fp8kv-sm86:/etc/club3090/fa2:ro"
        "${club3090}/models/qwen3.6-27b/vllm/patches/vllm-pr48375-mamba-drop-eagle-block:/etc/club3090/pr48375:ro"
        "${club3090}/models/qwen3.6-27b/vllm/patches/vllm-gdn-mtp-async-spec-order:/etc/club3090/gdn-async-order:ro"
        "${club3090}/models/qwen3.8-27b/vllm/patches/vllm-51581-dflash-dense-kv:/etc/club3090/dflash-dense-kv:ro"
        "${club3090}/models/qwen3.8-27b/vllm/patches/vllm-flashinfer-decode-pin:/etc/club3090/flashinfer-decode-pin:ro"
        "${club3090}/models/qwen3.8-27b/vllm/patches/qwen38-reasoning-effort-template/chat_template.jinja:/models/target/chat_template.jinja:ro"
        "${club3090}/scripts/detect_nvlink.sh:/etc/club3090/detect_nvlink.sh:ro"
        "${./vllm-swap/entrypoint.sh}:/etc/club3090/entrypoint.sh:ro"
        "fa2-kernels:/opt/club3090/fa2-artifacts:ro"
        "torch-compile:/root/.cache/vllm/torch_compile_cache"
        "triton-cache:/root/.triton/cache"
      ]
      ++ lib.optional patchEmbedding "${embeddingPatch}:/etc/club3090/qwen3_5-embed-quant.patch:ro";
    in
    {
      name = project;
      services = {
        fa2-init = {
          image = "ghcr.io/antonprokopyev/fa2-fp8kv-sm86@sha256:da040941fa048fd5fdfce520503341c0beda4ce41436a1c1fecaf3f8a99777c7";
          container_name = "${container}-fa2-init";
          pull_policy = "never";
          restart = "no";
          volumes = [ "fa2-kernels:/export" ];
        };

        vllm = {
          image = "vllm/vllm-openai:v0.29.0@sha256:c2914767605584b6d8f45686b82de173ecc99e781897aa3d0a66dacd72c51ae1";
          container_name = container;
          pull_policy = "never";
          restart = "no";
          user = "0:1000";
          ipc = "host";
          shm_size = "16gb";
          depends_on.fa2-init.condition = "service_completed_successfully";
          ports = [ "127.0.0.1:\${LLAMA_SWAP_PORT:-${toString fallbackPort}}:8000" ];
          devices = [ "nvidia.com/gpu=all" ];
          inherit volumes;
          environment = {
            TARGET_MODEL = "/models/target";
            DRAFT_MODEL = "/models/draft";
            SERVED_MODEL_NAME = servedModelName;
            PATCH_EMBEDDING = if patchEmbedding then "1" else "0";
            TP = "2";
            HF_HUB_OFFLINE = "1";
            TRANSFORMERS_OFFLINE = "1";
            NVIDIA_VISIBLE_DEVICES = "all";
            VLLM_WORKER_MULTIPROC_METHOD = "spawn";
            FA2_ARTIFACT_ID = "731d1942112a7cf35be4f0add0919072c06cac47e3bad4f674ff0157edad0e3f";
            NVLINK_MODE = "auto";
            DISABLE_CUSTOM_ALL_REDUCE = "0";
            NCCL_CUMEM_ENABLE = "0";
            NCCL_P2P_DISABLE = "1";
            VLLM_NO_USAGE_STATS = "1";
            VLLM_USE_FLASHINFER_SAMPLER = "0";
            OMP_NUM_THREADS = "1";
            PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
          };
          entrypoint = [
            "bash"
            "/etc/club3090/entrypoint.sh"
          ];
          command = [
            "--model"
            "/models/target"
            "--served-model-name"
            servedModelName
            "--quantization"
            quantization
            "--dtype"
            "bfloat16"
            "--tensor-parallel-size"
            "2"
            "--max-model-len"
            "60000"
            "--gpu-memory-utilization"
            "0.65"
            "--max-num-seqs"
            "1"
            "--max-num-batched-tokens"
            "8192"
            "--long-prefill-token-threshold"
            "4096"
            "--kv-cache-dtype"
            "fp8_e4m3"
            "--attention-backend"
            "FLASH_ATTN"
            "--trust-remote-code"
            "--enable-prefix-caching"
            "--enable-chunked-prefill"
            "--reasoning-parser"
            "qwen3"
            "--enable-auto-tool-choice"
            "--tool-call-parser"
            "qwen3_coder"
            "--default-chat-template-kwargs"
            ''{"enable_thinking": false, "reasoning_effort": "low"}''
            "--enable-prompt-tokens-details"
            "--host"
            "0.0.0.0"
            "--port"
            "8000"
          ];
        };
      };
      volumes = {
        fa2-kernels.name = "${project}-fa2-kernels";
        torch-compile.name = "${project}-torch-compile-v0.29-w4a16";
        triton-cache.name = "${project}-triton-v0.29-w4a16";
      };
    };

  normalCompose = composeFormat.generate "qwen38-normal-compose.yaml" (mkCompose {
    suffix = "normal";
    targetModel = normalModel;
    servedModelName = "qwen3.8-27b";
    quantization = "auto_round";
    patchEmbedding = false;
    fallbackPort = 18080;
  });

  uncensoredCompose = composeFormat.generate "qwen38-uncensored-compose.yaml" (mkCompose {
    suffix = "uncensored";
    targetModel = uncensoredModel;
    servedModelName = "qwen3.8-27b-uncensored";
    quantization = "compressed-tensors";
    patchEmbedding = true;
    fallbackPort = 18081;
  });

  composeFarmConfig = composeFormat.generate "llama-swap-compose-farm.yaml" {
    compose_dir = "/etc/llama-swap/stacks";
    hosts.local = {
      address = "127.0.0.1";
      user = "basnijholt";
    };
    stacks = {
      qwen38-normal = "local";
      qwen38-uncensored = "local";
    };
  };

  launcherConfig = jsonFormat.generate "llama-swap-vllm.json" {
    inherit cf;
    cfConfig = "/etc/llama-swap/compose-farm.yaml";
    docker = "${pkgs.docker}/bin/docker";
    stateDir = "/run/llama-swap-vllm";
    stopTimeout = 90;
    legacyContainers = [ "club-3090-vllm" ];
    models = {
      normal = {
        stack = "qwen38-normal";
        service = "vllm";
        container = "llama-swap-qwen38-normal";
      };
      uncensored = {
        stack = "qwen38-uncensored";
        service = "vllm";
        container = "llama-swap-qwen38-uncensored";
      };
    };
  };

  retireLegacyContainer = pkgs.writeShellScript "retire-club-3090-vllm" ''
    set -euo pipefail

    set +e
    state="$(${pkgs.docker}/bin/docker inspect --format '{{.State.Running}}' club-3090-vllm 2>&1)"
    inspect_status=$?
    set -e

    if ((inspect_status != 0)); then
      diagnostic="''${state,,}"
      case "$diagnostic" in
        *"no such object:"* | *"no such container:"*) exit 0 ;;
        *)
          echo "cannot inspect legacy container club-3090-vllm: $state" >&2
          exit "$inspect_status"
          ;;
      esac
    fi

    ${pkgs.docker}/bin/docker update --restart=no club-3090-vllm >/dev/null
    case "$state" in
      true) ${pkgs.docker}/bin/docker stop --time 90 club-3090-vllm >/dev/null ;;
      false) ;;
      *)
        echo "unexpected legacy container running state: $state" >&2
        exit 1
        ;;
    esac
  '';

  bundle = pkgs.runCommand "llama-swap-vllm-bundle" { } ''
    mkdir -p \
      "$out/bin" \
      "$out/etc/llama-swap/stacks/qwen38-normal" \
      "$out/etc/llama-swap/stacks/qwen38-uncensored"
    ln -s ${launcher}/bin/vllm-swap "$out/bin/vllm-swap"
    ln -s ${config.environment.etc."llama-swap/config.yaml".source} "$out/etc/llama-swap/config.yaml"
    ln -s ${launcherConfig} "$out/etc/llama-swap/vllm.json"
    ln -s ${composeFarmConfig} "$out/etc/llama-swap/compose-farm.yaml"
    ln -s ${normalCompose} "$out/etc/llama-swap/stacks/qwen38-normal/compose.yaml"
    ln -s ${uncensoredCompose} "$out/etc/llama-swap/stacks/qwen38-uncensored/compose.yaml"
  '';
in
{
  environment.systemPackages = [ launcher ];

  environment.etc = {
    "llama-swap/vllm.json".source = launcherConfig;
    "llama-swap/compose-farm.yaml".source = composeFarmConfig;
    "llama-swap/stacks/qwen38-normal/compose.yaml".source = normalCompose;
    "llama-swap/stacks/qwen38-uncensored/compose.yaml".source = uncensoredCompose;
  };

  system.build = {
    llama-swap-vllm = bundle;
    llama-swap-vllm-launcher = launcher;
  };

  systemd.services.llama-swap-vllm-retire-legacy = {
    description = "Retire legacy Club3090 vLLM container";
    wantedBy = [ "multi-user.target" ];
    before = [
      "llama-swap.service"
      "llama-swap-port-8010.socket"
    ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = retireLegacyContainer;
      RemainAfterExit = true;
      TimeoutStartSec = "120s";
    };
  };

  systemd.services.llama-swap = {
    after = [
      "docker.service"
      "llama-swap-vllm-retire-legacy.service"
    ];
    requires = [
      "docker.service"
      "llama-swap-vllm-retire-legacy.service"
    ];
    path = [ pkgs.docker ];
    unitConfig.RequiresMountsFor = [
      cf
      normalModel
      uncensoredModel
      draftModel
    ];
    serviceConfig = {
      RuntimeDirectory = "llama-swap-vllm";
      RuntimeDirectoryMode = "0750";
      RuntimeDirectoryPreserve = "restart";
      ExecStopPost = "${launcher}/bin/vllm-swap --config /etc/llama-swap/vllm.json cleanup";
      TimeoutStopSec = "240s";
    };
  };

  systemd.sockets.llama-swap-port-8010 = {
    description = "Compatibility listener for the former Club3090 vLLM endpoint";
    wantedBy = [ "multi-user.target" ];
    after = [ "llama-swap-vllm-retire-legacy.service" ];
    before = [
      "multi-user.target"
      "shutdown.target"
    ];
    conflicts = [ "shutdown.target" ];
    requires = [ "llama-swap-vllm-retire-legacy.service" ];
    unitConfig.DefaultDependencies = false;
    listenStreams = [ "0.0.0.0:8010" ];
  };

  systemd.services.llama-swap-port-8010 = {
    description = "Proxy port 8010 to llama-swap";
    after = [
      "llama-swap.service"
      "llama-swap-vllm-retire-legacy.service"
    ];
    requires = [
      "llama-swap.service"
      "llama-swap-vllm-retire-legacy.service"
    ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:9292";
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
