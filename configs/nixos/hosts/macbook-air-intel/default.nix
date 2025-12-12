{ pkgs, ... }:

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
    extraConfig = ''
      IdleAction=suspend
      IdleActionSec=30m
    '';
  };

  # concise power management: udev triggers inhibitor service when AC connects
  systemd.services.ac-idle-block = {
    description = "Inhibit idle suspend when on AC";
    serviceConfig.ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=ac-udev --mode=block sleep infinity";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start ac-idle-block.service"
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl stop ac-idle-block.service"
  '';

  environment.systemPackages = [
    (pkgs.stdenvNoCC.mkDerivation {
      pname = "get-apple-firmware";
      version = "360156db52c03dbdac0ef9d6e2cebbca46b955b";
      src = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/t2linux/wiki/360156db52c03dbdac0ef9d6e2cebbca46b955b/docs/tools/firmware.sh";
        hash = "sha256-IL7omNdXROG402N2K9JfweretTnQujY67wKKC8JgxBo=";
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        cp $src $out/bin/get-apple-firmware
        chmod +x $out/bin/get-apple-firmware
      '';
      meta.mainProgram = "get-apple-firmware";
    })
  ];
}
