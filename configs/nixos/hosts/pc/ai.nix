# AI and machine learning services (Ollama, llama-swap, Wyoming, Qdrant)
{ pkgs, ... }:

{
  # --- Ollama ---
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "0.0.0.0";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "1h";
      # Restrict Ollama to GPU 0 only, leaving GPU 1 for llama-swap
      CUDA_VISIBLE_DEVICES = "0";
    };
  };

  # --- llama-swap Service ---
  # Transparent proxy for automatic model swapping with llama.cpp
  # GPT-OSS chat template directly from HuggingFace
  environment.etc."llama-templates/openai-gpt-oss-20b.jinja".source = pkgs.fetchurl {
    url = "https://huggingface.co/unsloth/gpt-oss-20b-GGUF/resolve/main/template";
    sha256 = "sha256-UUaKD9kBuoWITv/AV6Nh9t0z5LPJnq1F8mc9L9eaiUM=";
  };

  environment.etc."llama-templates/apriel-thinker.jinja".source = ./apriel-thinker.jinja;

  environment.etc."llama-swap/config.yaml".text = ''
    # llama-swap configuration
    # This config uses llama.cpp's server to serve models on demand

    models:  # Ordered from newest to oldest

      # TODO: Not in cache yet - run script after downloading
      "nemotron-3-nano:30b-q4":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Nemotron-3-Nano-30B-A3B-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 512
          --threads 1
          --jinja

      # Uploaded 2025-12-10, size 13.5 GB, max ctx: 393216, layers: 40
      "devstral-2:24b-q4":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 65536
          --jinja

      # Uploaded 2025-12-10, size 27.0 GB, max ctx: 393216, layers: 40
      "devstral-2:24b-q8":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:UD-Q8_K_XL
          --port ''${PORT}
          --ctx-size 65536
          --jinja

      # Uploaded 2025-12-10, size 57.7 GB, max ctx: 262144, layers: 88
      "devstral-2:123b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Devstral-2-123B-Instruct-2512-GGUF:UD-Q3_K_XL
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 512
          --ubatch-size 512
          --split-mode layer
          --tensor-split 1.3,3
          --threads 8
          --jinja

      # Uploaded 2025-11-30, size 82.3 GB, max ctx: 131072, layers: 36
      "gpt-oss:120b-derestricted":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf Calandracas/gpt-oss-120b-Derestricted-GGUF
          --hf-file gpt-oss-120B-Derestricted-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 512
          --ubatch-size 512
          --split-mode layer
          --tensor-split 1.3,3
          --n-cpu-moe 24
          --threads 8
          --chat-template-kwargs '{"reasoning_effort": "high"}'
          --jinja

      # Uploaded 2025-11-28, size 42.9 GB, max ctx: 262144, layers: 48
      "qwen3-next-80b-a3b:q4_k_xl":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 512
          --split-mode layer
          --tensor-split 1,1
          --n-cpu-moe 10
          --threads 8
          --jinja

      # Uploaded 2025-10-31, size 4.4 GB, max ctx: 262144, layers: 36
      "qwen3-vl-thinking:4b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf Qwen/Qwen3-VL-4B-Thinking-GGUF:Q8_0
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-10-31, size 4.4 GB, max ctx: 262144, layers: 36
      "qwen3-vl:4b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf Qwen/Qwen3-VL-4B-Instruct-GGUF:Q8_0
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-10-31, size 8.8 GB, max ctx: 262144, layers: 36
      "qwen3-vl-thinking:8b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf Qwen/Qwen3-VL-8B-Thinking-GGUF:Q8_0
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-10-31, size 8.8 GB, max ctx: 262144, layers: 36
      "qwen3-vl:8b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf Qwen/Qwen3-VL-8B-Instruct-GGUF:Q8_0
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-10-30, size 18.6 GB, max ctx: 262144, layers: 64
      "qwen3-vl-thinking:32b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Qwen3-VL-32B-Thinking-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 32768
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-10-30, size 18.7 GB, max ctx: 262144, layers: 64
      "qwen3-vl:32b-q4":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Qwen3-VL-32B-Instruct-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 32768
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-10-30, size 36.8 GB, max ctx: 262144, layers: 64
      "qwen3-vl:32b-q8":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Qwen3-VL-32B-Instruct-GGUF:UD-Q8_K_XL
          --port ''${PORT}
          --ctx-size 16384
          --batch-size 2048
          --ubatch-size 512
          --threads 1
          --jinja

      # Uploaded 2025-10-23, size 32.4 GB, max ctx: 262144, layers: 64
      "qwen3-vl-thinking-abliterated:32b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf huihui-ai/Huihui-Qwen3-VL-32B-Thinking-abliterated
          --hf-file GGUF/ggml-model-q8_0.gguf
          --mmproj-url https://huggingface.co/huihui-ai/Huihui-Qwen3-VL-32B-Thinking-abliterated/resolve/main/GGUF/mmproj-model-f16.gguf
          --port ''${PORT}
          --ctx-size 16384
          --batch-size 2048
          --ubatch-size 512
          --threads 1
          --jinja

      # Uploaded 2025-10-02, size 16.8 GB, max ctx: 262400, layers: 48
      "apriel-thinker:15b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Apriel-1.5-15b-Thinker-GGUF:UD-Q8_K_XL
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --chat-template-file /etc/llama-templates/apriel-thinker.jinja

      # Uploaded 2025-09-04, size 0.3 GB, max ctx: 2048, layers: 24
      "embeddinggemma:300m":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf ggml-org/embeddinggemma-300M-GGUF
          --port ''${PORT}
          --embeddings
          --batch-size 2048
          --ubatch-size 2048

      # Uploaded 2025-08-27, size 39.6 GB, max ctx: 131072, layers: 80
      "hermes-4:70b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Hermes-4-70B-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 16384
          --batch-size 512
          --ubatch-size 512
          --gpu-layers 70
          --n-cpu-moe 11
          --threads 1
          --jinja

      # Uploaded 2025-08-24, size 20.5 GB, max ctx: 524288, layers: 64
      "seed-oss:36b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Seed-OSS-36B-Instruct-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-08-06, size 2.4 GB, max ctx: 262144, layers: 36
      "qwen3-thinking:4b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-4B-Thinking-2507-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 0

      # Uploaded 2025-08-05, size 59.0 GB, max ctx: 131072, layers: 36
      "gpt-oss:120b-q8":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/gpt-oss-120b-GGUF:q8_0
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 512
          --ubatch-size 512
          --split-mode layer
          --tensor-split 1.8,1
          --n-cpu-moe 13
          --threads 8
          --chat-template-kwargs '{"reasoning_effort": "high"}'
          --jinja

      # settings: https://www.reddit.com/r/LocalLLaMA/comments/1oo7kqy/comment/nn2dn8l/
      # settings: https://www.reddit.com/r/LocalLLaMA/comments/1n61mm7/comment/nc99fji/
      # question: https://www.reddit.com/r/LocalLLaMA/comments/1ow1v5i/help_whats_the_absolute_cheapest_build_to_run_oss/

      # Uploaded 2025-08-05, size 68.0 GB, max ctx: 131072, layers: 47
      "glm-4.5-air:ud-q4_k_xl":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/GLM-4.5-Air-GGUF
          --hf-file UD-Q4_K_XL/GLM-4.5-Air-UD-Q4_K_XL-00001-of-00002.gguf
          --port ''${PORT}
          --ctx-size 131072
          --batch-size 2048
          --ubatch-size 512
          --tensor-split 28,20
          --n-cpu-moe 20
          --no-mmap
          --no-context-shift
          --swa-full
          --threads 8
          --jinja

      # Uploaded 2025-08-02, size 11.3 GB, max ctx: 131072, layers: 24
      "gpt-oss-low:20b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf ggml-org/gpt-oss-20b-GGUF
          --port ''${PORT}
          --ctx-size 0
          --batch-size 4096
          --ubatch-size 2048
          --threads 1
          --chat-template-kwargs '{"reasoning_effort": "low"}'
          --jinja

      # Uploaded 2025-08-02, size 11.3 GB, max ctx: 131072, layers: 24
      "gpt-oss-medium:20b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf ggml-org/gpt-oss-20b-GGUF
          --port ''${PORT}
          --ctx-size 0
          --batch-size 4096
          --ubatch-size 2048
          --threads 1
          --chat-template-kwargs '{"reasoning_effort": "medium"}'
          --jinja

      # Uploaded 2025-08-02, size 11.3 GB, max ctx: 131072, layers: 24
      "gpt-oss-high:20b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf ggml-org/gpt-oss-20b-GGUF
          --port ''${PORT}
          --ctx-size 0
          --batch-size 4096
          --ubatch-size 2048
          --threads 1
          --chat-template-kwargs '{"reasoning_effort": "high"}'
          --jinja

      # Uploaded 2025-08-02, size 59.0 GB, max ctx: 131072, layers: 36
      "gpt-oss:120b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf ggml-org/gpt-oss-120b-GGUF
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 512
          --ubatch-size 512
          --split-mode layer
          --tensor-split 1.3,3
          --n-cpu-moe 15
          --threads 8
          --chat-template-kwargs '{"reasoning_effort": "high"}'
          --jinja

      # Uploaded 2025-07-31, size 16.5 GB, max ctx: 262144, layers: 48
      "qwen3-coder:30b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 131072

      # Uploaded 2025-07-07, size 13.3 GB, max ctx: 131072, layers: 40
      "devstral:24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo mistralai/Devstral-Small-2507_gguf:Q4_K_M
          --port ''${PORT}
          --ctx-size 65536
          --jinja

      # Best uncensored model according to https://www.reddit.com/r/LocalLLaMA/comments/1nq0cp9/important_why_abliterated_models_suck_here_is_a
      # Uploaded 2025-05-10, size 17.3 GB, max ctx: 40960, layers: 48
      "qwen3-30b-a3b-abliterated":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo mradermacher/Qwen3-30B-A3B-abliterated-erotic-i1-GGUF
          --port ''${PORT}
          --ctx-size 0
          --batch-size 4096
          --ubatch-size 2048
          --threads 1
          --jinja

      # Uploaded 2025-05-09, size 13.3 GB, max ctx: 32768, layers: 40
      "dolphin-mistral:24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-GGUF:Q4_K_M
          --port ''${PORT}
          --ctx-size 65536
          --jinja

      # Uploaded 2025-04-28, size 4.8 GB, max ctx: 131072, layers: 36
      "qwen3-thinking:8b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-8B-128K-GGUF:UD-Q4_K_XL
          --port ''${PORT}
          --ctx-size 0

      # Uploaded 2024-10-31, size 0.1 GB, max ctx: 8192, layers: 30
      "smollm2:135m":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/SmolLM2-135M-Instruct-GGUF:Q8_0
          --port ''${PORT}
          --ctx-size 0

      # Uploaded 2024-09-17, size 0.4 GB, max ctx: 32768, layers: 24
      "qwen2.5:0.5b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M
          --port ''${PORT}
          --ctx-size 0

    healthCheckTimeout: 3600  # 1 hour for large model download + loading

    # TTL keeps models in memory for specified seconds after last use
    ttl: 3600  # Keep models loaded for 1 hour (like OLLAMA_KEEP_ALIVE)

    # Groups allow running multiple models simultaneously
    groups:
      embedding:
        # Keep embedding model always loaded alongside any other model
        persistent: true  # Prevents other groups from unloading this
        swap: false       # Don't swap models within this group
        exclusive: false  # Don't unload other groups when loading this
        members:
          - "embeddinggemma:300m"
  '';

  systemd.services.llama-swap = {
    description = "llama-swap - OpenAI compatible proxy with automatic model swapping";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "basnijholt";
      Group = "users";
      ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config /etc/llama-swap/config.yaml --listen 0.0.0.0:9292 --watch-config";
      Restart = "always";
      RestartSec = 10;
      # Environment for CUDA support
      Environment = [
        "PATH=/run/current-system/sw/bin"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
        # llama-swap can use both GPUs (0,1), but Ollama is restricted to GPU 0
      ];
      # Environment needs access to cache directories for model downloads
      # Simplified security settings to avoid namespace issues
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # --- Wyoming Faster Whisper ---
  services.wyoming.faster-whisper = {
    servers.english = {
      enable = true;
      model = "large-v3-turbo";
      language = "en";
      device = "cuda";
      uri = "tcp://0.0.0.0:10300";
    };
    servers.dutch = {
      enable = false;
      model = "large-v3-turbo";
      language = "nl";
      device = "cuda";
      uri = "tcp://0.0.0.0:10301";
    };
  };

  # --- Wyoming Faster Whisper Hardening ---
  # Auto-restart on failure (including OOM kills)
  systemd.services.wyoming-faster-whisper-english = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
      # Memory limits to prevent system-wide OOM
      MemoryMax = "16G";
      MemoryHigh = "14G";
    };
  };

  # --- Wyoming Piper TTS ---
  services.wyoming.piper.servers.yoda = {
    enable = true;
    voice = "en-us-ryan-high";
    uri = "tcp://0.0.0.0:10200";
    useCUDA = true;
  };

  # --- Wyoming OpenWakeWord ---
  services.wyoming.openwakeword = {
    enable = true;
    uri = "tcp://0.0.0.0:10400";
  };

  # --- Qdrant Vector Database ---
  services.qdrant = {
    enable = true;
    settings = {
      storage = {
        storage_path = "/var/lib/qdrant/storage";
        snapshots_path = "/var/lib/qdrant/snapshots";
      };
      service = {
        host = "0.0.0.0";
        http_port = 6333;
      };
      telemetry_disabled = true;
    };
  };
}
