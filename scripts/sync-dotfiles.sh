#!/usr/bin/env bash

# Check if "install" parameter was provided
INSTALL_MODE=${1:-sync}
echo "🛠️ Running in ${INSTALL_MODE} mode"

# List of hosts to connect to
HOSTS=(
  # Physical hosts
  "nuc"
  "pc"
  "hp"
  "pi3"
  "pi4"
  # systemd-nspawn hosts
  "docker-truenas"
  "debian-truenas"
  # VM/LXC hosts
  "nix-cache"
  "docker"
  # Cloud hosts
  "ubuntu-hetzner"
  "nixos-hetzner"
)

# Arrays to track results
SUCCESSFUL_HOSTS=()
FAILED_HOSTS=()

# Loop through each host
for host in "${HOSTS[@]}"; do
  echo "===== 📡 Processing $host 📡 ====="

  scp ~/.local/bin/sync-local-dotfiles "$host":.local/bin/sync-local-dotfiles
  ssh "$host" "~/.local/bin/sync-local-dotfiles $INSTALL_MODE"

  # Check if the SSH command was successful
  if [ $? -eq 0 ]; then
    echo "✅ Successfully updated dotfiles on $host"
    SUCCESSFUL_HOSTS+=("$host")
  else
    echo "❌ Failed to update dotfiles on $host"
    FAILED_HOSTS+=("$host")
  fi
  
  echo ""
done

# Print summary
echo "📊 SUMMARY 📊"
echo "--------------"
echo "✅ Successful (${#SUCCESSFUL_HOSTS[@]}): ${SUCCESSFUL_HOSTS[*]}"
echo "❌ Failed (${#FAILED_HOSTS[@]}): ${FAILED_HOSTS[*]}"
echo "--------------"

# Final status
if [ ${#FAILED_HOSTS[@]} -eq 0 ]; then
  echo "🎉 All hosts processed successfully!"
  exit 0
else
  echo "⚠️ Some hosts failed. Check the logs above for details."
  exit 1
fi