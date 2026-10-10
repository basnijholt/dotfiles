# iMessage must run in the logged-in user's GUI session on a Mac.
{ config, lib, pkgs, ... }:

let
  cfg = config.local.imessage;
  homeDir = "/Users/${config.system.primaryUser}";
  stateDir = "${homeDir}/Library/Application Support/mautrix-imessage";
  bridgeArchive = pkgs.fetchurl {
    url = "https://mau.dev/mautrix/imessage/-/jobs/95972/artifacts/download";
    hash = "sha256-qpnnA8+dx261KaykJJ8opS6w/e2wVbNCbWz00lHYnT4=";
  };
  bridgePackage = pkgs.runCommand "mautrix-imessage-300ba6d0"
    {
      nativeBuildInputs = [ pkgs.unzip ];
      # Preserve the upstream ad-hoc signature for macOS privacy permissions.
      dontFixup = true;
    } ''
    unzip ${bridgeArchive} -d bridge
    mkdir -p "$out/bin" "$out/share/mautrix-imessage"
    install -m 0755 bridge/mautrix-imessage "$out/bin/mautrix-imessage"
    install -m 0644 bridge/libolm.3.dylib "$out/bin/libolm.3.dylib"
    install -m 0644 bridge/example-config.yaml "$out/share/mautrix-imessage/example-config.yaml"
  '';
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
  settingsFile = pkgs.writeText "imessage-settings.json" (builtins.toJSON cfg.settings);
in
{
  options.local.imessage = {
    enable = lib.mkEnableOption "the iMessage Matrix bridge";

    package = lib.mkOption {
      type = lib.types.package;
      default = bridgePackage;
      description = "Bridge package, including its example config and bundled libolm.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Non-secret bridge settings, merged over the private config.yaml at startup.
        Tokens remain in that user-owned file and must never be added here.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # TCC permissions refer to a stable executable path rather than a Nix store
    # path that changes on upgrades. Never copy the private config into the store.
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -m 0700 -o ${lib.escapeShellArg config.system.primaryUser} -g staff ${lib.escapeShellArg stateDir}
      for name in libolm.3.dylib mautrix-imessage; do
        if ! /usr/bin/cmp -s "${cfg.package}/bin/$name" "${stateDir}/$name"; then
          /usr/bin/install -m 0700 -o ${lib.escapeShellArg config.system.primaryUser} -g staff \
            "${cfg.package}/bin/$name" "${stateDir}/.$name.new"
          /bin/mv -f "${stateDir}/.$name.new" "${stateDir}/$name"
        fi
      done
      /usr/bin/install -m 0600 -o ${lib.escapeShellArg config.system.primaryUser} -g staff \
        ${cfg.package}/share/mautrix-imessage/example-config.yaml "${stateDir}/example-config.yaml"
    '';

    launchd.user.agents.imessage = {
      script = ''
        set -eu
        umask 077
        if [ ! -r "${stateDir}/config.yaml" ]; then
          echo "iMessage bridge: create the private ${stateDir}/config.yaml first" >&2
          exit 1
        fi
        ${python}/bin/python3 ${./imessage-config.py} \
          "${cfg.package}/share/mautrix-imessage/example-config.yaml" \
          "${stateDir}/config.yaml" ${settingsFile}
        if ! "${stateDir}/mautrix-imessage" --check-permissions >/dev/null 2>&1; then
          echo "iMessage bridge: grant Full Disk Access to ${stateDir}/mautrix-imessage" >&2
          until "${stateDir}/mautrix-imessage" --check-permissions >/dev/null 2>&1; do
            sleep 30
          done
        fi
        exec "${stateDir}/mautrix-imessage" --config "${stateDir}/config.yaml"
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        WorkingDirectory = stateDir;
        Umask = 63; # 0077
        EnvironmentVariables.PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
        StandardOutPath = "${stateDir}/launchagent.stdout.log";
        StandardErrorPath = "${stateDir}/launchagent.stderr.log";
      };
    };
  };
}
