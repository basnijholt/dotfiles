{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: dev-vm is a lightweight development environment
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];
}
