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
    let
      mkDarwin =
        {
          isPersonal,
          primaryUser,
          extraModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          modules = [
            ./configuration.nix
            ./homebrew.nix
            ./t3code.nix
            {
              options = {
                isPersonal = nixpkgs.lib.mkOption {
                  type = nixpkgs.lib.types.bool;
                  default = false;
                };
              };
              config.isPersonal = isPersonal;
              config.system.primaryUser = primaryUser;
            }
          ]
          ++ extraModules;
        };
    in
    {
      darwinConfigurations = {
        "basnijholt-macbook-pro" = mkDarwin {
          isPersonal = true;
          primaryUser = "basnijholt";
        };
        "basnijholt-macbook-pro-2" = mkDarwin {
          isPersonal = false;
          primaryUser = "bas.nijholt";
        };
        # M2 Pro that stays on with its lid closed, used remotely
        "basnijholt-macbook-pro-m2" = mkDarwin {
          isPersonal = true;
          primaryUser = "basnijholt";
          extraModules = [
            ./always-on.nix
            {
              # Pinned so a name collision on the LAN can't turn it into "-3",
              # which breaks darwin-rebuild's LocalHostName flake lookup
              networking.hostName = "basnijholt-macbook-pro-m2";
              networking.computerName = "basnijholt-macbook-pro-m2";
              local.t3code = {
                enable = true;
                host = "100.64.0.27";
              };
            }
          ];
        };
      };
    };
}
