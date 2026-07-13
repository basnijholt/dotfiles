# Shared configuration for personal MindRoom companion-bot LXC containers
# (mindroom-spouse, mindroom-mom, ...). MindRoom only — hosts that also run
# OpenClaw (e.g. mindroom-spouse) layer that on themselves.
#
# Each host additionally provides:
#   - networking.nix with its own networking.hostName
#   - secrets/agent-runtime.env.age with that person's runtime credentials
#     (decrypted via the container's SSH host key, see optional/agent-env.nix)
{
  config,
  pkgs,
  ...
}:

let
  homeDir = config.users.users.basnijholt.home;
  mindroomDir = "${homeDir}/.mindroom";
  agentRuntimeEnvPath = config.age.secrets.agent-runtime-env.path;
  agentIntegrationsEnvPath = config.age.secrets.agent-integrations-env.path;
  agentToolingEnvPath = config.age.secrets.agent-tooling-env.path;
  # Telegram belongs to OpenClaw where present; keep it out of MindRoom.
  mindroomUnsetEnvironment = [
    "OPENCLAW_TELEGRAM_BOT_TOKEN"
    "TELEGRAM_BOT_TOKEN"
  ];
in
{
  imports = [
    ./git-repo-checkouts.nix
    ./agent-env.nix
    ../hosts/mindroom/mindroom.nix
  ];

  systemd.tmpfiles.rules = [
    "d ${mindroomDir} 0750 basnijholt users - -"
  ];

  systemd.services.mindroom = {
    description = "MindRoom AI Agent System";
    after = [ "network-online.target" "git-checkout-mindroom.service" ];
    wants = [ "network-online.target" "git-checkout-mindroom.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "basnijholt";
      Group = "users";
      WorkingDirectory = mindroomDir;
      EnvironmentFile = [
        agentRuntimeEnvPath
        agentIntegrationsEnvPath
        agentToolingEnvPath
        "${mindroomDir}/.env"
      ];
      UnsetEnvironment = mindroomUnsetEnvironment;
      Environment = [
        "MINDROOM_CONFIG_PATH=${mindroomDir}/config.yaml"
        "MINDROOM_STORAGE_PATH=${mindroomDir}/mindroom_data"
      ];
      ExecStart = "${pkgs.writeShellScript "run-mindroom" ''
        export PATH="${pkgs.coreutils}/bin:${pkgs.uv}/bin:/run/current-system/sw/bin:$PATH"
        export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:''${LD_LIBRARY_PATH:-}"
        exec uv run --python ${pkgs.python313}/bin/python3 \
          --project "/srv/mindroom" \
          --directory "${mindroomDir}" \
          mindroom run
      ''}";
      Restart = "on-failure";
      RestartSec = "10s";
      TimeoutStopSec = "15s";
      KillMode = "mixed";
      SuccessExitStatus = "143 SIGTERM";
    };
  };
}
