{ pkgs, ... }:

{
  # --- AI & Machine Learning ---
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    host = "0.0.0.0";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "1h";
      # Restrict Ollama to GPU 0 only, leaving GPU 1 for llama-swap
      CUDA_VISIBLE_DEVICES = "0";
    };
  };

  # --- llama-swap service ---
  # Transparent proxy for automatic model swapping with llama.cpp

  # GPT-OSS chat template directly from HuggingFace
  environment.etc."llama-templates/openai-gpt-oss-20b.jinja".source = pkgs.fetchurl {
    url = "https://huggingface.co/unsloth/gpt-oss-20b-GGUF/resolve/main/template";
    sha256 = "sha256-UUaKD9kBuoWITv/AV6Nh9t0z5LPJnq1F8mc9L9eaiUM=";
  };

  environment.etc."llama-swap/config.yaml".text = ''
    # llama-swap configuration
    # This config uses llama.cpp's server to serve models on demand

    models:
      # Small models
      # Released 2024-09-17
      "qwen2.5-0.5b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/Qwen2.5-0.5B-Instruct-GGUF
          --hf-file Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 0

      # Released 2024-10-31
      "smollm2-135m":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/SmolLM2-135M-Instruct-GGUF
          --hf-file SmolLM2-135M-Instruct-Q8_0.gguf
          --port ''${PORT}
          --ctx-size 0

      # Best uncensored model according to https://www.reddit.com/r/LocalLLaMA/comments/1nq0cp9/important_why_abliterated_models_suck_here_is_a
      # Released 2025-07-11
      "qwen3-30b-a3b-abliterated":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf mradermacher/Qwen3-30B-A3B-abliterated-erotic-i1-GGUF
          --port ''${PORT}
          --ctx-size 0
          --batch-size 4096
          --ubatch-size 2048
          --threads 1
          --jinja

      # Coding models
      # Released 2025-08-08
      "qwen3-coder-30b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF
          --hf-file Qwen3-Coder-30B-A3B-q4_k_m.gguf
          --port ''${PORT}
          --ctx-size 0

      # Released 2025-07-23
      "devstral-24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo mistralai/Devstral-Small-2507_gguf
          --hf-file Devstral-Small-2507-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 0

      # Released 2025-07-07
      "dolphin-mistral-24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-GGUF
          --hf-file cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 0

      # Released 2025-09-11
      "qwen3-thinking-4b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf unsloth/Qwen3-4B-Thinking-2507-GGUF
          --port ''${PORT}
          --ctx-size 0
  
      # Released 2025-05-25
      "qwen3-thinking-8b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf unsloth/Qwen3-8B-128K-GGUF
          --port ''${PORT}
          --ctx-size 0

      # Released 2025-08-27
      "hermes-4:70b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Hermes-4-70B-GGUF
          --port ''${PORT}
          --ctx-size 0
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Released 2025-10-31
      "qwen3-vl-thinking:32b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Qwen3-VL-32B-Thinking-GGUF
          --port ''${PORT}
          --ctx-size 16384
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Released 2025-10-31
      "qwen3-vl:32b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Qwen3-VL-32B-Instruct-GGUF
          --port ''${PORT}
          --ctx-size 32768
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Released 2025-08-24
      "seed-oss:36b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf unsloth/Seed-OSS-36B-Instruct-GGUF
          --port ''${PORT}
          --ctx-size 32768
          --batch-size 2048
          --ubatch-size 2048
          --threads 1
          --jinja

      # Released 2025-10-30
      "gpt-oss:20b":
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

      # Released 2025-10-30
      "gpt-oss:120b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf ggml-org/gpt-oss-120b-GGUF
          --port ''${PORT}
          --ctx-size 65536
          --batch-size 512
          --ubatch-size 512
          --split-mode layer
          --tensor-split 3,1.3
          --n-cpu-moe 15
          --threads 8
          --chat-template-kwargs '{"reasoning_effort": "high"}'
          --jinja

      # settings: https://www.reddit.com/r/LocalLLaMA/comments/1oo7kqy/comment/nn2dn8l/
      # settings: https://www.reddit.com/r/LocalLLaMA/comments/1n61mm7/comment/nc99fji/
      # question: https://www.reddit.com/r/LocalLLaMA/comments/1ow1v5i/help_whats_the_absolute_cheapest_build_to_run_oss/

      # Released 2025-08-25
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

      # Released 2025-09-04
      "embeddinggemma:300m":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          -hf ggml-org/embeddinggemma-300M-GGUF
          --port ''${PORT}
          --embeddings

    healthCheckTimeout: 600  # 10 minutes for large model download + loading

    # TTL keeps models in memory for specified seconds after last use
    ttl: 3600  # Keep models loaded for 1 hour (like OLLAMA_KEEP_ALIVE)
    # Groups allow running multiple models simultaneously
    # Uncomment and adjust based on your VRAM (24GB RTX 3090)
    # groups:
    #   small:  # ~2-4GB VRAM total
    #     - "qwen2.5-0.5b"
    #     - "smollm2-135m"
    #     - "qwen3-thinking-4b"
    #   coding:  # Can't run both together (~15-20GB each)
    #     - "qwen3-coder-30b"
    #     - "devstral-small-22b"
    #   large:  # ~13-15GB VRAM each
    #     - "dolphin-mistral-24b"
    #     - "gpt-oss-20b"
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

  services.wyoming.faster-whisper = {
    servers.english = {
      enable = true;
      model = "large-v3";
      language = "en";
      device = "cuda";
      uri = "tcp://0.0.0.0:10300";
    };
    servers.dutch = {
      enable = false;
      model = "large-v3";
      language = "nl";
      device = "cuda";
      uri = "tcp://0.0.0.0:10301";
    };
  };

  # Auto-restart faster-whisper on failure (including OOM kills)
  systemd.services.wyoming-faster-whisper-english = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
      # Memory limits to prevent system-wide OOM
      MemoryMax = "16G";
      MemoryHigh = "14G";
    };
  };

  services.wyoming.piper.servers.yoda = {
    enable = true;
    voice = "en-us-ryan-high";
    uri = "tcp://0.0.0.0:10200";
    useCUDA = true;
  };

  services.wyoming.openwakeword = {
    enable = true;
    uri = "tcp://0.0.0.0:10400";
  };

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
