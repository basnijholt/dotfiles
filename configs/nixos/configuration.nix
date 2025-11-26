# NixOS configuration entry point
#
# 3-Tier Module Architecture:
#   - common/:   Modules shared by ALL hosts (Tier 1)
#   - optional/: Modules hosts can opt-in to (Tier 2)
#   - hosts/:    Host-specific modules (Tier 3)
{ ... }:

{
  imports = [ ./common ];

  system.stateVersion = "25.05";
}
