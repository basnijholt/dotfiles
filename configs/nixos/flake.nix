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

        # To test the HP configuration in a VM with Disko partitioning:
        # 1. Build: nix build .#nixosConfigurations.hp-vm.config.system.build.vmWithDisko
        # 2. Run:   ./result/bin/disko-vm -nographic
        hp-vm = mkHost [
          disko.nixosModules.disko
          ./hosts/hp/disko-vm.nix
          ./hosts/hp/hardware-configuration.nix
          ./hosts/hp/default.nix
          ({ modulesPath, lib, ... }: {
            networking.hostName = lib.mkForce "hp-vm";

            # Virtualization-friendly settings
            boot.loader.grub.device = lib.mkForce "/dev/vda";
            services.qemuGuest.enable = true;
            disko.memSize = 4096;

            # Set a password for root for easy login
            users.users.root.password = "nixos";

            # Rename VM interface to match hardware config for testing
            # Force rename the first ethernet device (eth0) to eno1 so systemd-networkd finds it
            services.udev.extraRules = ''
              SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth*", NAME="eno1"
            '';
          })
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
        hp-vm = (import ./hosts/hp/disko-vm.nix) { inherit lib; };
      };

    };
}
