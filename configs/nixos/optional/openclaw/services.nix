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
  openclawTelegramUnsetEnvironment = [
    "OPENCLAW_TELEGRAM_BOT_TOKEN"
    "TELEGRAM_BOT_TOKEN"
  ];
  openclawStateDir = "${homeDir}/.openclaw";
  openclawWorkingDirectory = "${openclawStateDir}/workspace";
  openclawConfigPath = "${openclawStateDir}/openclaw.json";
  openclawLogPath = "${openclawStateDir}/logs/gateway.log";
  openclawPackage = pkgs.openclaw;
  openclawRuntimePolicyPatch = pkgs.writeText "openclaw-runtime-policy.json" ''
    {
      "tools": {
        "exec": {
          "host": "gateway"
        }
      },
      "channels": {
        "telegram": {
          "webhookUrl": null,
          "webhookSecret": null,
          "webhookPath": null,
          "webhookHost": null,
          "webhookPort": null
        }
      }
    }
  '';
  openclawApplyRuntimePolicy = pkgs.writeShellScript "openclaw-apply-runtime-policy" ''
    if ! ${openclawPackage}/bin/openclaw config patch --help 2>&1 | ${pkgs.gnugrep}/bin/grep -q -- '--stdin'; then
      exit 0
    fi
    exec ${openclawPackage}/bin/openclaw config patch --stdin < ${openclawRuntimePolicyPatch}
  '';
  openclawInteractiveWrapper = pkgs.writeShellScriptBin "openclaw" ''
    export HOME=${lib.escapeShellArg homeDir}
    export OPENCLAW_CONFIG_PATH=${lib.escapeShellArg openclawConfigPath}
    export OPENCLAW_NIX_MODE=0
    export OPENCLAW_STATE_DIR=${lib.escapeShellArg openclawStateDir}

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

    exec ${openclawPackage}/bin/openclaw "$@"
  '';
  openclawCliPackage = pkgs.symlinkJoin {
    name = "openclaw-cli";
    paths = [
      openclawPackage
      openclawInteractiveWrapper
    ];
    postBuild = ''
      rm -f $out/bin/openclaw
      ln -s ${openclawInteractiveWrapper}/bin/openclaw $out/bin/openclaw
    '';
  };
in
{
  config = {
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
          OPENCLAW_NIX_MODE = "0";
          OPENCLAW_STATE_DIR = openclawStateDir;
        };
        path = with pkgs; [ bash coreutils docker git openssh signal-cli uv ];
        serviceConfig = {
          User = "basnijholt";
          Group = "users";
          WorkingDirectory = openclawWorkingDirectory;
          EnvironmentFile = openclawGatewayEnvironmentFiles;
          ExecStartPre = openclawApplyRuntimePolicy;
          ExecStart = "${openclawPackage}/bin/openclaw gateway --port 18789";
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
          UnsetEnvironment = openclawTelegramUnsetEnvironment;
          SuccessExitStatus = "143 SIGTERM";
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
  };
}
