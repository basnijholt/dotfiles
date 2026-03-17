{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.users.users.basnijholt.home;
  agentRuntimeEnvPath = config.age.secrets.agent-runtime-env.path;
  agentIntegrationsEnvPath = config.age.secrets.agent-integrations-env.path;
  agentToolingEnvPath = config.age.secrets.agent-tooling-env.path;
  openclawGatewayEnvironmentFiles = [
    agentRuntimeEnvPath
    agentIntegrationsEnvPath
    agentToolingEnvPath
  ];
  openclawStateDir = "${homeDir}/.openclaw";
  openclawWorkingDirectory = "${openclawStateDir}/workspace";
  openclawConfigPath = "${openclawStateDir}/openclaw.json";
  openclawLogPath = "${openclawStateDir}/logs/gateway.log";
  openclawInteractiveWrapper = pkgs.writeShellScriptBin "openclaw" ''
    export HOME=${lib.escapeShellArg homeDir}
    export OPENCLAW_CONFIG_PATH=${lib.escapeShellArg openclawConfigPath}
    export OPENCLAW_STATE_DIR=${lib.escapeShellArg openclawStateDir}
    export CLAWDBOT_CONFIG_PATH=${lib.escapeShellArg openclawConfigPath}
    export CLAWDBOT_STATE_DIR=${lib.escapeShellArg openclawStateDir}

    for env_file in \
      ${lib.escapeShellArg agentRuntimeEnvPath} \
      ${lib.escapeShellArg agentIntegrationsEnvPath} \
      ${lib.escapeShellArg agentToolingEnvPath}
    do
      [ -r "$env_file" ] || continue
      set -a
      . "$env_file"
      set +a
    done

    exec ${pkgs.openclaw}/bin/openclaw "$@"
  '';
  openclawCliPackage = pkgs.symlinkJoin {
    name = "openclaw-cli";
    paths = [
      pkgs.openclaw
      openclawInteractiveWrapper
    ];
    postBuild = ''
      rm -f $out/bin/openclaw
      ln -s ${openclawInteractiveWrapper}/bin/openclaw $out/bin/openclaw
    '';
  };
in
{
  nixpkgs.overlays = [
    (import ./overlay.nix)
  ];

  environment.systemPackages = [ openclawCliPackage ];

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
        EnvironmentFile = [ agentRuntimeEnvPath ];
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
