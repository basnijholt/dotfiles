# flake.nix
{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
    }:
    {
      darwinConfigurations = {
        "basnijholt-macbook-pro" = nix-darwin.lib.darwinSystem {
          modules = [
            ./configuration.nix
            ./homebrew.nix
            {
              options = {
                isPersonal = nixpkgs.lib.mkOption {
                  type = nixpkgs.lib.types.bool;
                  default = false;
                };
              };
              config.isPersonal = true;
              config.system.primaryUser = "basnijholt";
            }
          ];
        };
        "basnijholt-macbook-pro-2" = nix-darwin.lib.darwinSystem {
          modules = [
            ./configuration.nix
            ./homebrew.nix
            {
              options = {
                isPersonal = nixpkgs.lib.mkOption {
                  type = nixpkgs.lib.types.bool;
                  default = false;
                };
              };
              config.isPersonal = false;
              config.system.primaryUser = "bas.nijholt";
            }
          ];
        };
      };
    };
}
