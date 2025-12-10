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
  hp = "ssh-ed25519 AAAA_REPLACE_WITH_HP_KEY";
  nuc = "ssh-ed25519 AAAA_REPLACE_WITH_NUC_KEY";
  pc = "ssh-ed25519 AAAA_REPLACE_WITH_PC_KEY";
  pi3 = "ssh-ed25519 AAAA_REPLACE_WITH_PI3_KEY";
  pi4 = "ssh-ed25519 AAAA_REPLACE_WITH_PI4_KEY";

  # Virtual machines
  swarm-vm = "ssh-ed25519 AAAA_REPLACE_WITH_SWARM_VM_KEY";

  # =============================================================================
  # Host groups
  # =============================================================================
  swarmManagers = [ hp nuc swarm-vm ];
  piHosts = [ pi3 pi4 ];
  allHosts = [ hp nuc pc pi3 pi4 swarm-vm ];

in
{
  # =============================================================================
  # WiFi credentials
  # Format: WIFI_PSK=yourpassword
  # =============================================================================
  "wifi-psk.age".publicKeys = piHosts;

  # =============================================================================
  # Docker Swarm tokens
  # =============================================================================
  "swarm-manager.token.age".publicKeys = swarmManagers;
  "swarm-worker.token.age".publicKeys = allHosts;
}
