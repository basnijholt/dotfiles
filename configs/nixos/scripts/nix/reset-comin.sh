#!/usr/bin/env bash
# Reset comin state on all hosts to force rebuild
# Usage: ./reset-comin.sh [host1 host2 ...]

set -euo pipefail

# Default hosts with comin enabled
DEFAULT_HOSTS=(nuc pc pi4 hp nixos-hetzner)

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
