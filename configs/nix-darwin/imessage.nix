# iMessage must run in the logged-in user's GUI session on a Mac.
{ config, lib, pkgs, ... }:

let
  stateDir = "/Users/${config.system.primaryUser}/Library/Application Support/mautrix-imessage";
  bridgeArchive = pkgs.fetchurl {
    url = "https://mau.dev/mautrix/imessage/-/jobs/95972/artifacts/download";
    hash = "sha256-qpnnA8+dx261KaykJJ8opS6w/e2wVbNCbWz00lHYnT4=";
  };
  bridgePackage = pkgs.runCommand "mautrix-imessage-300ba6d0-arm64"
    {
      nativeBuildInputs = [ pkgs.unzip pkgs.cctools ];
      # Preserve the upstream ad-hoc signature for macOS privacy permissions.
      dontFixup = true;
    } ''
    unzip ${bridgeArchive} -d bridge
    mkdir -p "$out/bin"
    # Use the signed ARM64 slice; the Intel slice is unsigned.
    lipo bridge/mautrix-imessage -thin arm64 -output bridge/mautrix-imessage-arm64
    install -m 0755 bridge/mautrix-imessage-arm64 "$out/bin/mautrix-imessage"
    install -m 0644 bridge/libolm.3.dylib "$out/bin/libolm.3.dylib"
  '';
in
{
  # Keep the executable path stable for macOS privacy permissions.
  system.activationScripts.postActivation.text = ''
    /usr/bin/install -d -m 0700 -o ${lib.escapeShellArg config.system.primaryUser} -g staff ${lib.escapeShellArg stateDir}
    for name in libolm.3.dylib mautrix-imessage; do
      if ! /usr/bin/cmp -s "${bridgePackage}/bin/$name" "${stateDir}/$name"; then
        /usr/bin/install -m 0700 -o ${lib.escapeShellArg config.system.primaryUser} -g staff \
          "${bridgePackage}/bin/$name" "${stateDir}/.$name.new"
        /bin/mv -f "${stateDir}/.$name.new" "${stateDir}/$name"
      fi
    done
  '';

  launchd.user.agents.imessage.serviceConfig = {
    ProgramArguments = [ "${stateDir}/mautrix-imessage" "--config" "${stateDir}/config.yaml" ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    WorkingDirectory = stateDir;
    Umask = 63; # 0077
    EnvironmentVariables.PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
    StandardOutPath = "${stateDir}/launchagent.stdout.log";
    StandardErrorPath = "${stateDir}/launchagent.stderr.log";
  };
}
