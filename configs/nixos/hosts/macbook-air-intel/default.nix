{ ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: Intel MacBook Air
    ../../optional/virtualization.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
  ];

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "ignore";
  };
}
