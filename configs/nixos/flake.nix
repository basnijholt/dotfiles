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

      mkHost = { system ? "x86_64-linux", modules }:
        lib.nixosSystem {
          inherit system;
          modules = modules;
        };

      baseModules = [
        ./configuration.nix
      ];

      homeManagerModules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];

      hosts = {
        nixos = {
          system = "x86_64-linux";
          modules =
            [
              disko.nixosModules.disko
              ./disko/4tb-ssd.nix
            ]
            ++ baseModules
            ++ [ ./hosts/pc/default.nix ]
            ++ [ ./hardware-configuration.nix ]
            ++ homeManagerModules;
        };

        nuc = {
          system = "x86_64-linux";
          modules =
            baseModules
            ++ homeManagerModules
            ++ [ ./hosts/nuc/default.nix ];
        };
      };
    in {
      nixosConfigurations = lib.mapAttrs (_name: host: mkHost host) hosts;

      diskoConfigurations.nvme1 = import ./disko/4tb-ssd.nix;
    };
}
