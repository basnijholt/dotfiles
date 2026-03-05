{
  gatewayTokenEnv,
  telegramBotTokenEnv,
  llmProxyApiKeyEnv,
  signalAccountEnv,
}:
{
  config,
  pkgs,
  openclaw-patched,
  ...
}:
let
  homeDir = config.users.users.basnijholt.home;
  openclawGatewayEnvPath = config.age.secrets.openclaw-gateway-env.path;
  openclawIntegrationsEnvPath = config.age.secrets.openclaw-integrations-env.path;
  openclawAgentCliEnvPath = config.age.secrets.openclaw-agent-cli-env.path;
  openclawEnvironmentFiles = [
    openclawGatewayEnvPath
    openclawIntegrationsEnvPath
    openclawAgentCliEnvPath
  ];
  openclawStateDir = "${homeDir}/.openclaw";
  openclawWorkingDirectory = "${openclawStateDir}/workspace";
  openclawConfigPath = "/etc/openclaw/openclaw.json";
  openclawLogPath = "${openclawStateDir}/logs/gateway.log";
  openclawConfigFile = pkgs.writeText "openclaw.json" (
    builtins.toJSON (
      import ../home/openclaw/openclaw-config.nix {
        inherit gatewayTokenEnv telegramBotTokenEnv llmProxyApiKeyEnv signalAccountEnv;
      }
    )
  );
in
{
  nixpkgs.overlays = [
    (import ../home/openclaw/overlay.nix { inherit openclaw-patched; })
  ];

  environment.systemPackages = [ pkgs.openclaw ];

  # Match hetzner-matrix pattern: decrypt at activation with host SSH key.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets.openclaw-gateway-env = {
    file = ../home/openclaw/secrets/openclaw-gateway-env.age;
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };
  age.secrets.openclaw-integrations-env = {
    file = ../home/openclaw/secrets/openclaw-integrations-env.age;
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };
  age.secrets.openclaw-agent-cli-env = {
    file = ../home/openclaw/secrets/openclaw-agent-cli-env.age;
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };

  environment.etc."openclaw/openclaw.json" = {
    mode = "0644";
    source = openclawConfigFile;
  };

  systemd.tmpfiles.rules = [
    "d ${openclawStateDir} 0750 basnijholt users - -"
    "d ${openclawStateDir}/logs 0750 basnijholt users - -"
  ];

  systemd.services = {
    openclaw-gateway = {
      description = "OpenClaw gateway";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        OPENCLAW_CONFIG_PATH = openclawConfigPath;
        OPENCLAW_STATE_DIR = openclawStateDir;
        CLAWDBOT_CONFIG_PATH = openclawConfigPath;
        CLAWDBOT_STATE_DIR = openclawStateDir;
      };
      path = with pkgs; [ bash coreutils git openssh signal-cli uv ];
      serviceConfig = {
        User = "basnijholt";
        Group = "users";
        WorkingDirectory = openclawWorkingDirectory;
        EnvironmentFile = openclawEnvironmentFiles;
        ExecStart = "${pkgs.openclaw}/bin/openclaw gateway --port 18789";
        Restart = "always";
        RestartSec = 5;
        StandardOutput = "append:${openclawLogPath}";
        StandardError = "append:${openclawLogPath}";
      };
    };

    # Shared space watcher: push-notifies the agent when shared/ files change.
    openclaw-shared-watcher = {
      description = "OpenClaw Shared Space Watcher";
      after = [ "network.target" "openclaw-gateway.service" ];
      wants = [ "openclaw-gateway.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "basnijholt";
        Group = "users";
        Restart = "always";
        RestartSec = "5s";
        WorkingDirectory = openclawWorkingDirectory;
        EnvironmentFile = openclawEnvironmentFiles;
      };
      script = ''
        export HOME=${homeDir}
        export OPENCLAW_TOKENS="''$${gatewayTokenEnv}"
        exec ${pkgs.uv}/bin/uv run "${openclawWorkingDirectory}/shared/scripts/watcher.py" \
          "${openclawWorkingDirectory}/shared/" \
          --gateways 127.0.0.1:18789
      '';
      path = with pkgs; [ uv ];
    };

    # Git webhook pull listener: auto-pulls repos when Gitea receives a push.
    openclaw-git-pull-hook = {
      description = "OpenClaw Gitea webhook listener for auto-pull";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = "${openclawWorkingDirectory}/scripts/git-pull-hook.py";
      serviceConfig = {
        Type = "simple";
        User = "basnijholt";
        Group = "users";
        Restart = "always";
        RestartSec = "5s";
        WorkingDirectory = openclawWorkingDirectory;
        EnvironmentFile = openclawEnvironmentFiles;
        Environment = [
          "HOME=${homeDir}"
          "PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:/run/current-system/sw/bin"
        ];
        ExecStart = "${pkgs.uv}/bin/uv run ${openclawWorkingDirectory}/scripts/git-pull-hook.py --port 9876";
      };
    };
  };
}
