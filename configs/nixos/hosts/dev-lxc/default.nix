{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: dev-lxc is a lightweight development container
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];
}
