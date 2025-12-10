# Agenix secrets configuration
#
# This file maps SSH public keys to secrets. Each secret can only be
# decrypted by the hosts whose keys are listed.
#
# To get a host's public key:
#   ssh-keyscan -t ed25519 <hostname> 2>/dev/null | cut -d' ' -f2-
# Or from the host itself:
#   cat /etc/ssh/ssh_host_ed25519_key.pub
#
# To encrypt a secret:
#   cd configs/nixos/secrets
#   agenix -e swarm-manager.token.age
#
# To re-key all secrets after adding/removing keys:
#   agenix -r
let
  # Host SSH public keys (ed25519)
  # Get these with: ssh-keyscan -t ed25519 <host> | cut -d' ' -f2-
  hp = "ssh-ed25519 AAAA..."; # TODO: Replace with actual key
  nuc = "ssh-ed25519 AAAA..."; # TODO: Replace with actual key
  swarm-vm = "ssh-ed25519 AAAA..."; # TODO: Replace with actual key

  # Group definitions
  swarmManagers = [ hp nuc swarm-vm ];
  allHosts = [ hp nuc swarm-vm ];
in
{
  # Docker Swarm tokens - only managers need these
  "swarm-manager.token.age".publicKeys = swarmManagers;
  "swarm-worker.token.age".publicKeys = allHosts;
}
