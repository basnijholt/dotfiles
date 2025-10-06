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
      "qwen2.5-0.5b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/Qwen2.5-0.5B-Instruct-GGUF
          --hf-file Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 8192
          --n-gpu-layers 99
          --main-gpu 0

      "smollm2-135m":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/SmolLM2-135M-Instruct-GGUF
          --hf-file SmolLM2-135M-Instruct-Q8_0.gguf
          --port ''${PORT}
          --ctx-size 4096
          --n-gpu-layers 99
          --main-gpu 0

      # Coding models
      "qwen3-coder-30b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF
          --hf-file Qwen3-Coder-30B-A3B-q4_k_m.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --flash-attn

      "devstral-24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo mistralai/Devstral-Small-2507_gguf
          --hf-file Devstral-Small-2507-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --flash-attn

      # Large reasoning models
      "dolphin-mistral-24b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo bartowski/cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-GGUF
          --hf-file cognitivecomputations_Dolphin-Mistral-24B-Venice-Edition-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --flash-attn

      "qwen3-thinking-4b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/Qwen3-4B-Thinking-2507-GGUF
          --hf-file Qwen3-4B-Thinking-2507-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0

      "gpt-oss-20b":
        cmd: |
          ${pkgs.llama-cpp}/bin/llama-server
          --hf-repo unsloth/gpt-oss-20b-GGUF
          --hf-file gpt-oss-20b-Q4_K_M.gguf
          --port ''${PORT}
          --ctx-size 32768
          --n-gpu-layers 99
          --main-gpu 0
          --jinja
          --chat-template-file /etc/llama-templates/openai-gpt-oss-20b.jinja
          --reasoning-format auto
          --flash-attn
          --cont-batching
          --no-mmap
          --threads 12
          --parallel 2

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

  services.wyoming.piper.servers.yoda = {
    enable = true;
    voice = "en-us-ryan-high";
    uri = "tcp://0.0.0.0:10200";
    useCUDA = true;
  };

  services.wyoming.openwakeword = {
    enable = true;
    preloadModels = [ "alexa" "hey_jarvis" "ok_nabu" ];
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
