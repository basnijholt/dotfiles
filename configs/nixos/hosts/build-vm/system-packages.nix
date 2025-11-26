# Build server packages (extras beyond common/packages.nix)
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    attic-client
    iotop
    nix-output-monitor
  ];
}
