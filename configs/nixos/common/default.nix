# Common modules shared by ALL hosts
# This is Tier 1 of the 3-tier architecture
{ ... }:

{
  imports = [
    ./core.nix
    ./nix.nix
    ./nixpkgs.nix
    ./user.nix
    ./services.nix
    ./t3code.nix
    ./packages.nix
    ./disk-cleanup.nix
    ./home-manager.nix
    ./comin.nix
  ];
}
