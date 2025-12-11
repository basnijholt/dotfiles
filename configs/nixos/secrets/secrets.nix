# Agenix secrets configuration
#
# This file maps SSH public keys to secrets. Secrets can only be
# decrypted by hosts whose keys are listed.
#
# Setup:
#   1. Get host public keys:
#      ssh-keyscan -t ed25519 <hostname> 2>/dev/null | cut -d' ' -f2-
#      Or from the host: cat /etc/ssh/ssh_host_ed25519_key.pub
#
#   2. Add keys below and run: agenix -r (to re-key all secrets)
#
# Encrypt a secret:
#   cd configs/nixos/secrets
#   echo "WIFI_PSK=mypassword" | agenix -e wifi-psk.age
#   agenix -e swarm-manager.token.age  # then paste token
#
# Re-key after adding/removing hosts:
#   agenix -r
let
  # =============================================================================
  # Host SSH public keys (ed25519)
  # Get with: ssh-keyscan -t ed25519 <host> 2>/dev/null | cut -d' ' -f2-
  # =============================================================================

  # Physical hosts
  hp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5ZinYz3ul3fbg/+eA95t0dq0yBQw4UxBMyFKUihSTQ";
  nuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRL54JIesy0f1FtG81ABXq/xbNNyUFXTA5qZWNoW097";
  pc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjiKKO6ajlHe5oZa9fGI1v9yLvjvuBH3ZZlYlCIlREt";
  pi3 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINGj7EWu8KEtECwOgGnQQg/sLnqpgMQqHu2tNgFEe4oX";
  pi4 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINGj7EWu8KEtECwOgGnQQg/sLnqpgMQqHu2tNgFEe4oX";

  # Virtual machines (add key when VM is created)
  # swarm-vm = "ssh-ed25519 AAAA_REPLACE_WITH_SWARM_VM_KEY";

  # =============================================================================
  # Host groups
  # =============================================================================
  swarmManagers = [ hp nuc ]; # Add swarm-vm when created
  piHosts = [ pi3 pi4 ];
  allHosts = [ hp nuc pc pi3 pi4 ]; # Add swarm-vm when created

in
{
  # =============================================================================
  # WiFi credentials
  # Format: WIFI_SSID=MyNetwork\nWIFI_PSK=yourpassword
  # =============================================================================
  "wifi.age".publicKeys = piHosts;

  # =============================================================================
  # Docker Swarm tokens
  # =============================================================================
  "swarm-manager.token.age".publicKeys = swarmManagers;
  "swarm-worker.token.age".publicKeys = allHosts;
}
