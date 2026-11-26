# Temporary real-cloud DNS for the Ecovacs T80 ("T80 internet" switch in
# Home Assistant).
#
# CoreDNS here answers the robot's Ecovacs lookups with Bumper's address. While
# the switch is on, `t80-dns on` drops the robot's DNS to this host, so it falls
# back to 8.8.8.8 and gets the real cloud. Its DNS reaches hp directly when it
# sits on the AiMesh node, so the router cannot do this part.
#
# This only changes DNS answers: the router's firewall still decides whether the
# robot reaches the internet. Everything is runtime-only and fails back to
# Bumper: the auto-off timer, `off`, a reboot or a firewall reload (nftables
# flushes the ruleset) all remove the drop.
{ pkgs, ... }:

let
  robotIP = "192.168.1.125"; # DHCP reservation on the ASUS router
  haIP = "192.168.1.178";
  haKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBp18lyAIYH6dDVSaMBRBc0g4h+vo9lXS/2FMkmZOjjW ha-t80-net";

  t80Dns = pkgs.writeShellApplication {
    name = "t80-dns";
    runtimeInputs = [
      pkgs.nftables
      pkgs.systemd
    ];
    text = ''
      stop_timer() { systemctl stop t80-dns-off.timer 2>/dev/null || true; }

      case "''${1:-status}" in
      on)
        minutes=''${2:-60}
        case "$minutes" in "" | *[!0-9]*) minutes=60 ;; esac
        if ((minutes > 180)); then minutes=180; fi
        if ((minutes < 1)); then minutes=1; fi
        stop_timer
        nft -f - <<'EOF'
      table inet t80
      delete table inet t80
      table inet t80 {
        chain input {
          type filter hook input priority -10; policy accept;
          ip saddr ${robotIP} meta l4proto { tcp, udp } th dport 53 drop
        }
      }
      EOF
        systemd-run --quiet --collect --unit=t80-dns-off --on-active="''${minutes}m" \
          --timer-property=AccuracySec=1s ${placeholder "out"}/bin/t80-dns off
        echo "online for $minutes min"
        ;;
      off)
        stop_timer
        nft delete table inet t80 2>/dev/null || true
        echo offline
        ;;
      status)
        if nft list table inet t80 >/dev/null 2>&1; then echo online; else echo offline; fi
        ;;
      *)
        echo "usage: on [minutes] | off | status" >&2
        exit 2
        ;;
      esac
    '';
  };

  # Forced command of Home Assistant's key: only on/off/status get through.
  sshEntry = pkgs.writeShellScript "t80-dns-ssh" ''
    set -f
    # shellcheck disable=SC2086
    set -- $SSH_ORIGINAL_COMMAND
    case "''${1:-}" in
    on | off | status) exec /run/wrappers/bin/sudo ${t80Dns}/bin/t80-dns "$1" "''${2:-60}" ;;
    *)
      echo "usage: on [minutes] | off | status" >&2
      exit 2
      ;;
    esac
  '';
in
{
  users.groups.t80 = { };
  users.users.t80 = {
    isSystemUser = true;
    group = "t80";
    shell = pkgs.bash; # sshd runs the forced command through the login shell
    openssh.authorizedKeys.keys = [ ''restrict,from="${haIP}",command="${sshEntry}" ${haKey}'' ];
  };

  security.sudo.extraRules = [
    {
      users = [ "t80" ];
      commands = [
        {
          command = "${t80Dns}/bin/t80-dns";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
