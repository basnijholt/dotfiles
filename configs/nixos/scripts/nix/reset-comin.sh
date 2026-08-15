#!/usr/bin/env bash
# Reset comin state on all hosts to force rebuild
# Usage: ./reset-comin.sh [host1 host2 ...]

set -euo pipefail

# Deployed hosts with comin enabled. These are SSH aliases where the alias and
# NixOS hostname differ (for example, mindroom-mon is mindroom-mom).
DEFAULT_HOSTS=(pc nuc hp nas pi3 pi4 nix-cache docker-lxc gce-vm hetzner-matrix hetzner hetzner-saas mindroom mindroom-spouse mindroom-mon)

HOSTS=("${@:-${DEFAULT_HOSTS[@]}}")

for host in "${HOSTS[@]}"; do
  echo "=== $host ==="
  if ssh -o ConnectTimeout=5 "$host" "true" 2>/dev/null; then
    ssh -t "$host" "sudo rm -f /var/lib/comin/store.json && sudo systemctl restart comin" && \
      echo "✓ Reset comin on $host" || \
      echo "✗ Failed to reset comin on $host"
  else
    echo "✗ Cannot connect to $host"
  fi
done
