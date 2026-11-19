# app-hotkeys — global hotkeys that bring an app to the front, from a plain text file.
# Replaces Keyboard Maestro's "Open Apps" group with the same mechanism (Carbon
# RegisterEventHotKey + SetFrontProcessWithOptions); see configs/app-hotkeys/.
# Bindings: ~/.config/app-hotkeys/hotkeys.conf (linked by dotbot), reloaded on save.
# Log: ~/Library/Logs/app-hotkeys/current. Force a reload (e.g. after quitting KM):
#   launchctl kill HUP gui/$(id -u)/org.nixos.app-hotkeys
{ config, lib, pkgs, ... }:

let
  cfg = config.local.appHotkeys;
  homeDir = "/Users/${config.system.primaryUser}";
  logDir = "${homeDir}/Library/Logs/app-hotkeys";
  # Built with nixpkgs' Swift against nixpkgs' macOS SDK. It needs no TCC permission
  # (no event tap, no Accessibility), so a new /nix/store path after a rebuild is fine.
  package = pkgs.swiftPackages.stdenv.mkDerivation {
    name = "app-hotkeys";
    # Outside this flake's directory: works with the git flake (`nixswitch`), not a `path:` one
    src = ../app-hotkeys/app-hotkeys.swift;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.swift ];
    buildPhase = ''
      swiftc -O -module-name AppHotkeys -framework AppKit -framework Carbon $src -o app-hotkeys
    '';
    installPhase = ''
      install -Dm755 app-hotkeys $out/bin/app-hotkeys
    '';
    meta.mainProgram = "app-hotkeys";
  };
in
{
  options.local.appHotkeys = {
    enable = lib.mkEnableOption "the app-hotkeys user agent";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];

    launchd.user.agents.app-hotkeys = {
      script = ''
        # s6-log rotates the log (1 MB, 3 old files); exec keeps app-hotkeys as the job's process
        exec ${lib.getExe package} 2> >(exec ${pkgs.s6}/bin/s6-log n3 s1000000 ${logDir})
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        # Hotkeys need the GUI session; Interactive keeps launchd from throttling the response
        LimitLoadToSessionType = "Aqua";
        ProcessType = "Interactive";
        WorkingDirectory = homeDir;
      };
    };
  };
}
