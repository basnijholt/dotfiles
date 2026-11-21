{
  config,
  pkgs,
  ...
}:
let
  agentRuntimeEnvPath = config.age.secrets.agent-runtime-env.path;
  agentIntegrationsEnvPath = config.age.secrets.agent-integrations-env.path;
  agentToolingEnvPath = config.age.secrets.agent-tooling-env.path;
  mindroomPython = pkgs.python314;
  # Load the shared agenix env first so each runtime's own .env can override
  # Matrix/provisioning values without editing the shared secret bundle.
  agentEnvironmentFiles = [
    agentRuntimeEnvPath
    agentIntegrationsEnvPath
    agentToolingEnvPath
  ];
  mindroomUnsetEnvironment = [
    "OPENCLAW_TELEGRAM_BOT_TOKEN"
    "TELEGRAM_BOT_TOKEN"
  ];

  # Shared uv + python wrapper for mindroom CLI invocations.
  mindroom-uv = dir: args:
    pkgs.writeShellScript "mindroom-uv-${builtins.replaceStrings [" " "/"] ["-" "-"] args}" ''
      export PATH="${pkgs.coreutils}/bin:${pkgs.uv}/bin:/run/current-system/sw/bin:$PATH"
      export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:''${LD_LIBRARY_PATH:-}"
      export UV_PROJECT_ENVIRONMENT="${dir}/.venv-python314"
      exec uv run --python ${mindroomPython}/bin/python3 \
        --project "/srv/mindroom" \
        --extra matrix_calls \
        --directory "${dir}" \
        mindroom ${args}
    '';

  mindroom-avatar-service = {
    name,
    dir,
    extraEnvironment ? [ ],
  }: {
    description = "MindRoom avatar maintenance (${name})";
    after = [ name ];
    wants = [ name ];
    partOf = [ name ];
    wantedBy = [ name ];
    serviceConfig = {
      Type = "oneshot";
      User = "basnijholt";
      Group = "users";
      WorkingDirectory = dir;
      EnvironmentFile = agentEnvironmentFiles ++ [ "${dir}/.env" ];
      UnsetEnvironment = mindroomUnsetEnvironment;
      Environment = [
        "MINDROOM_CONFIG_PATH=${dir}/config.yaml"
        "MINDROOM_STORAGE_PATH=${dir}/mindroom_data"
        "MINDROOM_LOG_FORMAT=json"
        "MINDROOM_TIMING=1"
      ] ++ extraEnvironment;
    };
    script = ''
      ${mindroom-uv dir "avatars generate"} || true
      ${mindroom-uv dir "avatars sync"} || true
    '';
  };
in
{
  systemd.services = {
    # Public lab runtime: served at mindroom.lab.mindroom.chat but backed by the
    # local Tuwunel/API stack on this host. Runtime state lives in ~/.mindroom-lab.
    mindroom-lab = {
      description = "MindRoom AI Agent System (lab)";
      after = [ "network-online.target" "git-checkout-mindroom.service" ];
      wants = [ "network-online.target" "git-checkout-mindroom.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "basnijholt";
        Group = "users";
        WorkingDirectory = "/home/basnijholt/.mindroom-lab";
        EnvironmentFile = agentEnvironmentFiles ++ [ "/home/basnijholt/.mindroom-lab/.env" ];
        UnsetEnvironment = mindroomUnsetEnvironment;
        Environment = [
          "MINDROOM_CONFIG_PATH=/home/basnijholt/.mindroom-lab/config.yaml"
          "MINDROOM_STORAGE_PATH=/home/basnijholt/.mindroom-lab/mindroom_data"
          "MINDROOM_LOG_FORMAT=json"
          "MINDROOM_TIMING=1"
        ];
        ExecStart = "${mindroom-uv "/home/basnijholt/.mindroom-lab" "run"}";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "15s";
        KillMode = "mixed";
        SuccessExitStatus = "143 SIGTERM";
      };
    };

    # Hosted runtime: connects to the production Matrix domain mindroom.chat and
    # keeps its state separate from the lab runtime in ~/.mindroom-chat.
    mindroom-chat = {
      description = "MindRoom AI Agent System (mindroom.chat)";
      after = [ "network-online.target" "git-checkout-mindroom.service" ];
      wants = [ "network-online.target" "git-checkout-mindroom.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "basnijholt";
        Group = "users";
        WorkingDirectory = "/home/basnijholt/.mindroom-chat";
        EnvironmentFile = agentEnvironmentFiles ++ [ "/home/basnijholt/.mindroom-chat/.env" ];
        UnsetEnvironment = mindroomUnsetEnvironment;
        Environment = [
          "MINDROOM_CONFIG_PATH=/home/basnijholt/.mindroom-chat/config.yaml"
          "MINDROOM_STORAGE_PATH=/home/basnijholt/.mindroom-chat/mindroom_data"
          "MINDROOM_LOG_FORMAT=json"
          "MINDROOM_TIMING=1"
          "BACKEND_PORT=8766"
          # Public origin this runtime is reachable at (Caddy on host mindroom
          # routes the catch-all of mindroom.lab.mindroom.chat to this API on
          # :8766). Lets publish_report / OAuth / CORS emit absolute public URLs
          # instead of bare relative paths.
          "MINDROOM_PUBLIC_URL=https://mindroom.lab.mindroom.chat"
        ];
        ExecStart = "${mindroom-uv "/home/basnijholt/.mindroom-chat" "run --api-port 8766"}";
        Restart = "always";
        RestartSec = "10s";
        TimeoutStopSec = "15s";
        KillMode = "mixed";
        SuccessExitStatus = "143 SIGTERM";
      };
    };

    mindroom-lab-avatars = mindroom-avatar-service {
      name = "mindroom-lab.service";
      dir = "/home/basnijholt/.mindroom-lab";
    };

    mindroom-chat-avatars = mindroom-avatar-service {
      name = "mindroom-chat.service";
      dir = "/home/basnijholt/.mindroom-chat";
      extraEnvironment = [ "BACKEND_PORT=8766" ];
    };
  };
}
