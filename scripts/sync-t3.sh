#!/usr/bin/env bash
# Link this machine's T3 Code server with every other T3 host below, both
# ways, so agents on any of them can hand work to the others (delegate_task).
#
# Run it on the machine to connect: `sync-t3`. It reaches the other hosts over
# SSH (from dev-lxc, log in with a forwarded agent: `ssh -A`) and mints a
# short-lived pairing code on each side with `t3 pair`. Hosts that do not
# answer are skipped. Links expire after 30 days; run it again to renew them.
#
# The T3 server itself comes from Nix (`local.t3code` in configs/nixos and
# configs/nix-darwin). A new host also needs an entry in HOSTS and a Traefik
# route in /opt/stacks/traefik/dynamic.d/manual.yml on docker-lxc.
set -uo pipefail

# What the agents of one machine may do on the others
ACCESS=full-access

# hostname|ssh target|URL the other machines use. T3 refuses plain http for
# links, so these are the Traefik names (LAN and tailnet only).
HOSTS=(
  "pc|pc|https://t3.lab.nijho.lt"
  "basnijholt-macbook-pro-m2|macbook-m2|https://t3m.lab.nijho.lt"
  "basnijholt-macbook-pro-m5|macbook-m5|https://t3m5.lab.nijho.lt"
  "dev-lxc|basnijholt@192.168.1.84|https://t3dev.lab.nijho.lt"
)

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
  fs.writeFileSync(`${file}.tmp`, `${JSON.stringify(settings, null, 2)}\n`);
  fs.renameSync(`${file}.tmp`, file);
  console.log("changed");
}
'

remote() {
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" "$REMOTE_PATH $2"
}

token_of() {
  sed -n 's/^Token: //p'
}

# t3 looks for its server under a git worktree's own .t3 when run inside one
cd "$HOME" || exit 1

self=$(hostname -s)
self_url=""
for entry in "${HOSTS[@]}"; do
  IFS='|' read -r name _ url <<<"$entry"
  [ "$name" = "$self" ] && self_url=$url
done
if [ -z "$self_url" ]; then
  echo "❌ $self is not in HOSTS in $0; add it with the URL the other machines use."
  exit 1
fi

if ! command -v t3 >/dev/null; then
  echo "🛠️ Installing the T3 CLI"
  bash "$HOME/dotfiles/scripts/sync-bun.sh"
fi
if ! t3 environment list >/dev/null 2>&1; then
  echo "❌ No T3 Code server answers on $self. Enable local.t3code for this host in Nix."
  exit 1
fi
if [ "$(node - <<<"$ENABLE_LINKS")" = changed ]; then
  echo "🧪 Turned on Linked environments on $self"
  sleep 2
fi

LINKED=()
FAILED=()
for entry in "${HOSTS[@]}"; do
  IFS='|' read -r name target url <<<"$entry"
  [ "$name" = "$self" ] && continue
  echo "===== 🔗 $name ====="

  if ! state=$(remote "$target" "node -" <<<"$ENABLE_LINKS"); then
    echo "⚠️ Skipped: $name does not answer over SSH ($target)"
    FAILED+=("$name")
    continue
  fi
  if [ "$state" = changed ]; then
    echo "🧪 Turned on Linked environments on $name"
    sleep 2
  fi

  # This machine's agents on the other one
  token=$(remote "$target" "t3 pair --label $self --ttl $TTL" 2>/dev/null | token_of)
  if [ -z "$token" ]; then
    echo "⚠️ Skipped: no T3 server answered on $name"
    FAILED+=("$name")
    continue
  fi
  if ! t3 environment link "$url" --pairing-code "$token" --access "$ACCESS"; then
    echo "❌ Could not link $self to $name"
    FAILED+=("$name")
    continue
  fi

  # The other machine's agents on this one
  token=$(t3 pair --label "$name" --ttl "$TTL" | token_of)
  if ! remote "$target" "t3 environment link $self_url --pairing-code $token --access $ACCESS"; then
    echo "❌ Could not link $name to $self"
    FAILED+=("$name")
    continue
  fi
  LINKED+=("$name")
done

echo ""
echo "✅ Linked both ways (${#LINKED[@]}): ${LINKED[*]:-}"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "❌ Not linked (${#FAILED[@]}): ${FAILED[*]}"
  exit 1
fi
