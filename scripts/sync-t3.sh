#!/usr/bin/env bash
# Link every T3 Code host below with every other, both ways, so agents on any
# of them can hand work to the others (delegate_task).
#
# Run it on any machine that reaches the others over SSH: `sync-t3` (from
# dev-lxc, log in with a forwarded agent: `ssh -A`). For each link it mints a
# short-lived pairing code on the target with `t3 pair` and redeems it on the
# source. Hosts that do not answer are skipped. Links expire after 30 days; pc
# renews them every day (configs/nixos/hosts/pc/t3-links.nix).
#
# The T3 server itself comes from Nix (`local.t3code` in configs/nixos and
# configs/nix-darwin). A new host also needs an entry in HOSTS and a Traefik
# route in /opt/stacks/traefik/dynamic.d/manual.yml on docker-lxc.
set -uo pipefail

# What the agents of one machine may do on the others
ACCESS=full-access

# hostname|ssh target|URL the other machines use, and optionally |one-way
# for a host the others link to that links to none of them. The Macs are
# reached by their hostname (tailnet DNS), not an ~/.ssh/config alias that a
# Mac's own copy may lack. T3 refuses plain http for links, so the URLs are
# the Traefik names (LAN and tailnet only).
HOSTS=(
  "pc|pc|https://t3.lab.nijho.lt"
  "basnijholt-macbook-pro-m2|basnijholt-macbook-pro-m2|https://t3m2.lab.nijho.lt"
  "basnijholt-macbook-pro-m5|basnijholt-macbook-pro-m5|https://t3m5.lab.nijho.lt"
  "dev-lxc|basnijholt@192.168.1.84|https://t3dev.lab.nijho.lt"
)
# More hosts in the same format, kept out of this public repository
EXTRA_HOSTS=${XDG_CONFIG_HOME:-$HOME/.config}/sync-t3/hosts
if [ -f "$EXTRA_HOSTS" ]; then
  while IFS= read -r line; do
    case $line in "" | "#"*) continue ;; esac
    HOSTS+=("$line")
  done <"$EXTRA_HOSTS"
fi

TTL=2m
# The t3 launcher runs on node: Homebrew's on the Macs, the system's on NixOS.
# Non-interactive SSH shells have neither on PATH.
# shellcheck disable=SC2016 # expanded by the remote shell
REMOTE_PATH='export PATH=$HOME/.bun/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$PATH;'
export PATH="$HOME/.bun/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

# Turn on Settings -> Labs -> Linked environments. The server reloads
# settings.json when it changes. Prints "changed" when it was off.
# shellcheck disable=SC2016 # JavaScript template literals, not shell
ENABLE_LINKS='
const fs = require("fs");
const file = `${process.env.HOME}/.t3/userdata/settings.json`;
let settings = {};
try {
  settings = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
if (settings.linkedEnvironmentsEnabled !== true) {
  settings.linkedEnvironmentsEnabled = true;
  // A temp name per writer, so two runs linking the same host at once
  // cannot rename the temp file of the other
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(settings, null, 2)}\n`);
  fs.renameSync(tmp, file);
  console.log("changed");
}
'

token_of() {
  sed -n 's/^Token: //p'
}

# t3 looks for its server under a git worktree's own .t3 when run inside one
cd "$HOME" || exit 1

NAMES=() TARGETS=() URLS=() MODES=()
for entry in "${HOSTS[@]}"; do
  IFS='|' read -r name target url mode <<<"$entry"
  NAMES+=("$name") TARGETS+=("$target") URLS+=("$url") MODES+=("$mode")
done

self=$(hostname -s)
case " ${NAMES[*]} " in
  *" $self "*) ;;
  *)
    echo "❌ $self is not in HOSTS in $0; add it with the URL the other machines use."
    exit 1
    ;;
esac

if ! t3 environment list >/dev/null 2>&1; then
  echo "❌ No T3 Code server answers on $self. Install the CLI with sync-bun and enable local.t3code for this host in Nix."
  exit 1
fi

# Run a command on host number $1: here, or over SSH
on() {
  if [ "${NAMES[$1]}" = "$self" ]; then
    bash -c "$2"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=5 "${TARGETS[$1]}" "$REMOTE_PATH $2"
  fi
}

UP=()
SKIPPED=()
changed=""
for i in "${!NAMES[@]}"; do
  if ! state=$(on "$i" "node -" <<<"$ENABLE_LINKS"); then
    echo "⚠️ Skipped ${NAMES[$i]}: could not reach it over SSH (${TARGETS[$i]}) or turn on its Linked environments"
    SKIPPED+=("${NAMES[$i]}")
    continue
  fi
  if [ "$state" = changed ]; then
    echo "🧪 Turned on Linked environments on ${NAMES[$i]}"
    changed=1
  fi
  UP+=("$i")
done
if [ -n "$changed" ]; then
  sleep 2
fi

LINKED=0
FAILED=()
for i in "${UP[@]}"; do
  [ "${MODES[$i]}" = one-way ] && continue
  for j in "${UP[@]}"; do
    [ "$i" = "$j" ] && continue
    from=${NAMES[$i]}
    to=${NAMES[$j]}
    token=$(on "$j" "t3 pair --label $from --ttl $TTL" 2>/dev/null | token_of)
    if [ -z "$token" ]; then
      echo "❌ $from to $to: no pairing code from $to"
    elif ! on "$i" "t3 environment link ${URLS[$j]} --pairing-code $token --access $ACCESS" >/dev/null; then
      echo "❌ $from to $to: the link failed"
    else
      echo "🔗 $from to $to"
      LINKED=$((LINKED + 1))
      continue
    fi
    FAILED+=("$from to $to")
  done
done

echo ""
echo "✅ Linked: $LINKED"
if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo "⚠️ Skipped (${#SKIPPED[@]}): ${SKIPPED[*]}"
fi
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "❌ Not linked (${#FAILED[@]}):"
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi
