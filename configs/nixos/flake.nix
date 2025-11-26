{
  description = "Bas's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      commonModules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
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

    in {
      nixosConfigurations = {
        nixos = mkHost [
          disko.nixosModules.disko
          ./hosts/pc/disko.nix
          ./hosts/pc/hardware-configuration.nix
          ./hosts/pc/default.nix
        ];

        nuc = mkHost [
          disko.nixosModules.disko
          ./hosts/nuc/disko.nix
          ./hosts/nuc/hardware-configuration.nix
          ./hosts/nuc/default.nix
        ];

        hp = mkHost [
          disko.nixosModules.disko
          ./hosts/hp/disko.nix
          ./hosts/hp/hardware-configuration.nix
          ./hosts/hp/default.nix
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

        # Lightweight development VM for Incus
        dev-vm = mkHost [
          disko.nixosModules.disko
          ./hosts/dev-vm/disko.nix
          ./hosts/dev-vm/hardware-configuration.nix
          ./hosts/dev-vm/default.nix
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
        nvme1 = (import ./hosts/pc/disko.nix) { inherit lib; };
        nuc = (import ./hosts/nuc/disko.nix) { inherit lib; };
        hp = (import ./hosts/hp/disko.nix) { inherit lib; };
        dev-vm = (import ./hosts/dev-vm/disko.nix) { inherit lib; };
      };

    };
}
