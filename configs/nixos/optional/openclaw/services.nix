{
  config,
  pkgs,
  ...
}:
let
  homeDir = config.users.users.basnijholt.home;
  openclawHostSecretsDir = ../../hosts/${config.networking.hostName}/secrets;
  openclawSharedSecretsDir = ./secrets;
  openclawRuntimeEnvPath = config.age.secrets.openclaw-runtime-env.path;
  openclawIntegrationsEnvPath = config.age.secrets.openclaw-integrations-env.path;
  openclawToolingEnvPath = config.age.secrets.openclaw-tooling-env.path;
  openclawGatewayEnvironmentFiles = [
    openclawRuntimeEnvPath
    openclawIntegrationsEnvPath
    openclawToolingEnvPath
  ];
  openclawStateDir = "${homeDir}/.openclaw";
  openclawWorkingDirectory = "${openclawStateDir}/workspace";
  openclawConfigPath = "${openclawStateDir}/openclaw.json";
  openclawLogPath = "${openclawStateDir}/logs/gateway.log";
in
{
  nixpkgs.overlays = [
    (import ./overlay.nix)
  ];

  environment.systemPackages = [ pkgs.openclaw ];

  # Match hetzner-matrix pattern: decrypt at activation with host SSH key.
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets.openclaw-runtime-env = {
    file = openclawHostSecretsDir + "/openclaw-runtime.env.age";
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };
  age.secrets.openclaw-integrations-env = {
    file = openclawSharedSecretsDir + "/openclaw-integrations.env.age";
    owner = "basnijholt";
    group = "users";
    mode = "0400";
  };
  age.secrets.openclaw-tooling-env = {
    file = openclawSharedSecretsDir + "/openclaw-tooling.env.age";
    owner = "basnijholt";
    group = "users";
    mode = "0400";
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
      unitConfig.AssertPathExists = openclawConfigPath;
      environment = {
        HOME = homeDir;
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
        EnvironmentFile = openclawGatewayEnvironmentFiles;
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
        EnvironmentFile = [ openclawRuntimeEnvPath ];
      };
      script = ''
        export HOME=${homeDir}
        export OPENCLAW_TOKENS="$OPENCLAW_GATEWAY_TOKEN"
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
        Environment = [
          "HOME=${homeDir}"
          "PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:/run/current-system/sw/bin"
        ];
        ExecStart = "${pkgs.uv}/bin/uv run ${openclawWorkingDirectory}/scripts/git-pull-hook.py --port 9876";
      };
    };
  };
}
