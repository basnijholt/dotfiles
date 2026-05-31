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

    mindroom-cinny = {
      description = "MindRoom Web UI (Cinny fork)";
      after = [ "network-online.target" "git-checkout-cinny.service" ];
      wants = [ "network-online.target" "git-checkout-cinny.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ bash nodejs_22 ];
      serviceConfig = {
        Type = "simple";
        User = "basnijholt";
        Group = "users";
        WorkingDirectory = "/var/www/cinny";
        Environment = [
          "VITE_ALLOWED_HOSTS=chat.lab.mindroom.chat,127.0.0.1,localhost"
        ];
        ExecStart = "${pkgs.nodejs_22}/bin/npm start -- --host 127.0.0.1 --port 8090 --strictPort";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    mindroom-element-build = {
      description = "Build MindRoom Web UI (Element fork)";
      after = [ "network-online.target" "git-checkout-element.service" ];
      wants = [ "network-online.target" "git-checkout-element.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        bash
        coreutils
        git
        nodejs_22
        node-gyp
        pkg-config
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "basnijholt";
        Group = "users";
        WorkingDirectory = "/srv/mindroom-element";
      };
      script = ''
        set -euo pipefail
        cd /srv/mindroom-element

        current_rev="$(git rev-parse HEAD)"
        if [ -f webapp/index.html ] && [ -f .webapp-build-rev ] && [ "$(cat .webapp-build-rev)" = "$current_rev" ]; then
          exit 0
        fi

        cp config.mindroom.json config.json
        tmp_bin=".tmp-bin"
        trap 'rm -rf "$tmp_bin"' EXIT
        mkdir -p "$tmp_bin"
        cat > "$tmp_bin/pnpm" <<'EOF'
#!/usr/bin/env sh
exec corepack pnpm "$@"
EOF
        chmod +x "$tmp_bin/pnpm"
        export PATH="$PWD/$tmp_bin:$PATH"
        corepack pnpm install --frozen-lockfile
        corepack pnpm build
        echo "$current_rev" > .webapp-build-rev
      '';
    };

    mindroom-element = {
      description = "MindRoom Web UI (Element fork)";
      after = [ "network-online.target" "git-checkout-element.service" "mindroom-element-build.service" ];
      wants = [ "network-online.target" "git-checkout-element.service" "mindroom-element-build.service" ];
      requires = [ "mindroom-element-build.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "basnijholt";
        Group = "users";
        WorkingDirectory = "/srv/mindroom-element/webapp";
        ExecStart = "${pkgs.python3}/bin/python3 /srv/mindroom-element/serve.py 8091";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
