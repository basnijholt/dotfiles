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
          ./hosts/nuc/default.nix
        ];
      };

      diskoConfigurations.nvme1 = import ./hosts/pc/disko.nix;
    };
}
