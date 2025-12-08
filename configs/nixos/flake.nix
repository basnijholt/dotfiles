{
  description = "Bas's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, comin, nixos-raspberrypi, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      commonModules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        comin.nixosModules.comin
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];

      mkHost = extraModules:
        lib.nixosSystem {
          inherit system;
          modules = commonModules ++ extraModules;
        };

      mkPi = piModule: extraModules:
        nixos-raspberrypi.lib.nixosSystem {
          specialArgs = { inherit nixos-raspberrypi; };
          modules = [ piModule ] ++ commonModules ++ extraModules;
        };

      mkPiInstaller = piModule: extraModules:
        nixos-raspberrypi.lib.nixosInstaller {
          specialArgs = { inherit nixos-raspberrypi; };
          modules = [ piModule ] ++ extraModules;
        };

    in {
      nixosConfigurations = {
        pc = mkHost [
          disko.nixosModules.disko
          ./hosts/pc/disko.nix
          ./hosts/pc/default.nix
          ./hosts/pc/hardware-configuration.nix
        ];

        nuc = mkHost [
          disko.nixosModules.disko
          ./hosts/nuc/disko.nix
          ./hosts/nuc/default.nix
          ./hosts/nuc/hardware-configuration.nix
        ];

        hp = mkHost [
          disko.nixosModules.disko
          ./hosts/hp/disko.nix
          ./hosts/hp/default.nix
          ./hosts/hp/hardware-configuration.nix
        ];

        # Incus VM version of HP - same services/packages, VM-appropriate hardware
        hp-incus = mkHost [
          disko.nixosModules.disko
          ./hosts/hp/disko.nix
          ./hosts/hp/default.nix
          ./hosts/hp/incus-overrides.nix
        ];

        # Incus VM version of NUC - same services/packages, VM-appropriate hardware
        nuc-incus = mkHost [
          disko.nixosModules.disko
          ./hosts/nuc/disko.nix
          ./hosts/nuc/default.nix
          ./hosts/nuc/incus-overrides.nix
        ];

        # Incus VM version of PC - same services/packages, VM-appropriate hardware
        # GPU-dependent services (NVIDIA, CUDA, AI) build but won't function at runtime
        pc-incus = mkHost [
          disko.nixosModules.disko
          ./hosts/pc/disko.nix
          ./hosts/pc/default.nix
          ./hosts/pc/incus-overrides.nix
        ];

        # Lightweight development VM for Incus
        dev-vm = mkHost [
          disko.nixosModules.disko
          ./hosts/dev-vm/disko.nix
          ./hosts/dev-vm/default.nix
          ./hosts/dev-vm/hardware-configuration.nix
        ];

        # Lightweight development LXC container for Incus
        dev-lxc = mkHost [
          ./hosts/dev-lxc/default.nix
          ./hosts/dev-lxc/hardware-configuration.nix
        ];

        # Nix cache server VM for Incus - builds and caches NixOS configurations
        nix-cache = mkHost [
          ./hosts/nix-cache/default.nix
          ./hosts/nix-cache/hardware-configuration.nix
        ];

        # Raspberry Pi 4 - uses nixos-raspberrypi for hardware + ZFS on SSD
        pi4 = mkPi nixos-raspberrypi.nixosModules.raspberry-pi-4.base [
          disko.nixosModules.disko
          ./hosts/pi4/disko.nix
          ./hosts/pi4/default.nix
          ./hosts/pi4/hardware-configuration.nix
        ];

        # Raspberry Pi 3 - simple SD card setup with WiFi
        pi3 = mkPi nixos-raspberrypi.nixosModules.raspberry-pi-3.base [
          ./hosts/pi3/default.nix
          ./hosts/pi3/hardware-configuration.nix
        ];

        # Bootstrap SD images - minimal bootable images with WiFi + SSH
        # After booting: nixos-rebuild switch --flake .#pi3 (or pi4)
        pi3-bootstrap = mkPiInstaller nixos-raspberrypi.nixosModules.raspberry-pi-3.base [
          ./installers/pi-bootstrap.nix
        ];

        pi4-bootstrap = mkPiInstaller nixos-raspberrypi.nixosModules.raspberry-pi-4.base [
          ./installers/pi-bootstrap.nix
        ];

        installer = lib.nixosSystem {
          inherit system;
          modules = [
            (import (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"))
            ./installers/iso.nix
          ];
        };
      };

      diskoConfigurations = {
        pc = (import ./hosts/pc/disko.nix) { inherit lib; };
        nuc = (import ./hosts/nuc/disko.nix) { inherit lib; };
        hp = (import ./hosts/hp/disko.nix) { inherit lib; };
        dev-vm = (import ./hosts/dev-vm/disko.nix) { inherit lib; };
      };

    };
}
