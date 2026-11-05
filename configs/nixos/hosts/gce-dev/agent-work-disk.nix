# Encrypted disk for coding-agent credentials and data, mounted at /work.
#
# Never unlocked at boot and no keyfile anywhere: after every boot run
# `agent-work-disk unlock` (asks for the passphrase). While it is mounted, the
# agent-work-disk-guard unit locks it again the moment anyone else logs in;
# `sudo agent-work-disk-guard-test --pause-guard` tests that against a
# throwaway disk. The logic lives in agent-work-disk.py, the test in
# agent-work-disk-guard-test.py.
{
  lib,
  pkgs,
  utils,
  ...
}:

let
  user = "basnijholt";
  home = "/home/${user}";
  mountPoint = "/work";

  settings = {
    inherit user mountPoint;
    device = "/dev/disk/by-uuid/73bd3539-91df-4b69-a7e6-c9417bc641b5";
    mapper = "work";
    keysFile = "/etc/ssh/authorized_keys.d/${user}";
    guardUnit = "agent-work-disk-guard";
    # Paths in $HOME that are symlinks to <mountPoint>/config/<name>. While
    # the disk is locked they dangle, so the tools fail instead of writing
    # credentials to the plain boot disk. ~/dotfiles and ~/.cache stay put:
    # home-manager recreates both at boot.
    dirLinks = {
      ".claude" = "claude";
      ".code" = "code";
      ".codex" = "codex";
      ".config/gcloud" = "gcloud";
      ".config/gh" = "gh";
      ".docker" = "docker";
      ".gemini" = "gemini";
      ".local/share/amp" = "amp";
      ".local/share/opencode" = "opencode";
      ".local/state/opencode" = "opencode-state";
      ".paseo" = "paseo";
      ".pi" = "pi";
      ".t3" = "t3";
    };
    fileLinks = {
      ".claude.json" = "claude.json";
    };
  };

  agentWorkDisk = pkgs.runCommand "agent-work-disk" { buildInputs = [ pkgs.python3 ]; } ''
    install -Dm755 ${./agent-work-disk.py} $out/bin/agent-work-disk
    install -Dm755 ${./agent-work-disk-guard-test.py} $out/bin/agent-work-disk-guard-test
    python3 -c 'import ast, sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' $out/bin/*
    patchShebangs --host $out/bin
  '';
in
{
  fileSystems.${mountPoint} = {
    device = "/dev/mapper/${settings.mapper}";
    fsType = "ext4";
    options = [
      "noauto"
      "nofail"
      "noatime"
    ];
  };

  environment.etc."agent-work-disk.json".text = builtins.toJSON settings;

  # noauto mounts do not create their mount point. It stays root-owned, so
  # nothing can write to the plain disk while the disk is locked; the ":"
  # prefixes keep tmpfiles from resetting the owner of the mounted disk's
  # root, which `agent-work-disk unlock` gives to the user. tmpfiles never
  # replaces a real file or directory with a link; `unlock` moves those.
  systemd.tmpfiles.rules = [
    "d ${mountPoint} :0755 :root :root -"
  ]
  ++ lib.mapAttrsToList (src: dst: "L ${home}/${src} - - - - ${mountPoint}/config/${dst}") (
    settings.dirLinks // settings.fileLinks
  );

  # Armed whenever the disk is mounted, even by a plain `mount`: systemd also
  # starts a mount's Wants= when the mount appears outside systemd. It exits
  # after locking. Type=notify: starting it returns only once it has checked
  # the sessions that are already open, so `unlock` mounts after that.
  systemd.services.${settings.guardUnit} = {
    description = "Lock ${mountPoint} when anyone else logs in";
    wantedBy = [ "${utils.escapeSystemdPath mountPoint}.mount" ];
    after = [ "${utils.escapeSystemdPath mountPoint}.mount" ];
    serviceConfig = {
      Type = "notify";
      ExecStart = "${agentWorkDisk}/bin/agent-work-disk guard";
      Restart = "on-failure";
    };
  };

  # The user has a password, and the cloud serial console would offer a login
  # prompt that the guard cannot tell apart from the user's own session.
  # Kernel and boot output still reach the serial port.
  systemd.services."serial-getty@ttyS0".enable = false;

  environment.systemPackages = [
    agentWorkDisk
    pkgs.cryptsetup
    pkgs.psmisc
  ];
}
