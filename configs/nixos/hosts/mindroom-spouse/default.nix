{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDir = config.users.users.basnijholt.home;
  mindroomDir = "${homeDir}/.mindroom";
  agentRuntimeEnvPath = config.age.secrets.agent-runtime-env.path;
  agentIntegrationsEnvPath = config.age.secrets.agent-integrations-env.path;
  agentToolingEnvPath = config.age.secrets.agent-tooling-env.path;
in
{
  imports = [
    ../../optional/git-repo-checkouts.nix
    ./networking.nix
    ../../optional/agent-env.nix
    ../mindroom/mindroom.nix
    ../../optional/openclaw/services.nix
  ];

  # Passwordless sudo for OpenClaw agent
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # signal-cli for OpenClaw Signal channel
  environment.systemPackages = [ pkgs.signal-cli ];

  nixpkgs.config.permittedInsecurePackages = lib.mkAfter [ "openclaw-2026.4.21" ];

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
    };
  };

  # Deploy manually while this container is being used as a hands-on MindRoom
  # runtime.
  services.comin.enable = lib.mkForce false;
}
