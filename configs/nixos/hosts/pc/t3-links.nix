# Renew the links between the T3 Code hosts every day with sync-t3
# (scripts/sync-t3.sh); links expire after 30 days. Hosts that are off are
# skipped. ntfy `homelab` hears when a link fails, when no SSH agent on pc
# holds a key (after a reboot, until the keychain is unlocked), and when a
# link of pc expires within a week (a host that stayed unreachable).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDir = config.users.users.basnijholt.home;
  ntfyUrl = "http://100.64.0.28:8089/homelab";
in
{
  systemd.user.services.sync-t3 = {
    description = "Renew the links between the T3 Code hosts";
    onFailure = [ "sync-t3-alert.service" ];
    environment.PATH = lib.mkForce "${homeDir}/.bun/bin:/run/current-system/sw/bin";
    serviceConfig.Type = "oneshot";
    script = ''
      if ! SSH_AUTH_SOCK=$(${../../common/ssh-agent-sock.sh}); then
        echo "No SSH agent on pc holds a key; unlock the keychain"
        exit 1
      fi
      export SSH_AUTH_SOCK
      ${homeDir}/.local/bin/sync-t3
      soon=$(date -u -d "+7 days" +%FT%TZ)
      expiring=$(t3 environment list --json | jq -r --arg soon "$soon" '.[] | select(.expiresAt < $soon) | .label')
      if [ -n "$expiring" ]; then
        echo "Links that expire within a week:" $expiring
        exit 1
      fi
    '';
  };

  systemd.user.services.sync-t3-alert = {
    description = "Tell ntfy that renewing the T3 Code links failed";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.curl}/bin/curl -fsS -H "Title: T3 links on pc" -H "Tags: warning" \
        --data-binary "$(journalctl --user _SYSTEMD_USER_UNIT=sync-t3.service -n 5 -o cat)" \
        ${ntfyUrl}
    '';
  };

  # In the afternoon, when the Macs are likely awake
  systemd.user.timers.sync-t3 = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 14:00";
      Persistent = true;
    };
  };
}
