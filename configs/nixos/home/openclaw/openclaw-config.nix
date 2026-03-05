{ gatewayTokenEnv, telegramBotTokenEnv, llmProxyApiKeyEnv, signalAccountEnv }:
{
  gateway = {
    mode = "local";
    controlUi.allowInsecureAuth = true;
    auth = {
      mode = "token";
      # Resolved at runtime from env var via ${VAR} substitution
      token = "\${${gatewayTokenEnv}}";
    };
  };

  models = {
    mode = "merge";
    providers = {
      llm-proxy = {
        baseUrl = "http://192.168.1.6:4000/v1";
        # Resolved at runtime from env var via ${VAR} substitution
        apiKey = "\${${llmProxyApiKeyEnv}}";
        api = "openai-completions";
        models = [
          {
            id = "claude-opus-4-6";
            name = "Claude Opus 4.6";
            reasoning = false;
            input = [ "text" ];
            cost = { input = 5; output = 25; cacheRead = 0.50; cacheWrite = 6.25; };
            contextWindow = 200000;
            maxTokens = 16384;
          }
          {
            id = "claude-sonnet-4-6";
            name = "Claude Sonnet 4.6";
            reasoning = false;
            input = [ "text" ];
            cost = { input = 3; output = 15; cacheRead = 0.30; cacheWrite = 3.75; };
            contextWindow = 200000;
            maxTokens = 16384;
          }
          {
            id = "claude-haiku-4-5";
            name = "Claude Haiku 4.5";
            reasoning = false;
            input = [ "text" ];
            cost = { input = 1; output = 5; cacheRead = 0.10; cacheWrite = 1.25; };
            contextWindow = 200000;
            maxTokens = 16384;
          }
        ];
      };
    };
  };

  agents.defaults = {
    model.primary = "llm-proxy/claude-opus-4-6";
    contextPruning = { mode = "cache-ttl"; ttl = "1h"; };
    compaction.mode = "safeguard";
    compaction.reserveTokensFloor = 8000;
    heartbeat.every = "30m";
    maxConcurrent = 4;
    subagents.maxConcurrent = 8;

    # Use local embeddings (llama.cpp on 192.168.1.5) instead of OpenAI cloud
    memorySearch = {
      provider = "openai";
      model = "embeddinggemma:300m";
      remote = {
        baseUrl = "http://192.168.1.5:9292/v1";
        apiKey = "not-needed";
      };
    };
  };

  messages.ackReactionScope = "group-mentions";

  # Use local Kokoro TTS instead of Edge TTS (cloud)
  messages.tts = {
    provider = "openai";
    openai = {
      apiKey = "not-needed";
      model = "kokoro";
      voice = "af_bella";
    };
  };

  commands = {
    native = "auto";
    nativeSkills = "auto";
  };

  channels = {
    telegram = {
      enabled = true;
      # Resolved at runtime from env var via ${VAR} substitution
      botToken = "\${${telegramBotTokenEnv}}";
      dmPolicy = "pairing";
      groupPolicy = "allowlist";
      streamMode = "partial";
    };
    signal = {
      enabled = true;
      # Resolved at runtime from env var via ${VAR} substitution
      account = "\${${signalAccountEnv}}";
      cliPath = "/run/current-system/sw/bin/signal-cli";
      dmPolicy = "pairing";
      groupPolicy = "allowlist";
    };
  };

  skills.entries = {
    sherpa-onnx-tts = { enabled = true; };
    coding-agent = { enabled = true; };
  };

  hooks.internal = {
    enabled = true;
    entries = {
      location-enrich = { enabled = true; };
    };
  };

  plugins.entries = {
    telegram = { enabled = true; };
    signal = { enabled = true; };
  };
}
