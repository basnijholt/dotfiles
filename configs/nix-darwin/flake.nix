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
          privacyApps,
          primaryUser,
          extraModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          modules = [
            ./configuration.nix
            ./homebrew.nix
            ./t3code.nix
            ./paseo.nix
            ./charge-limit.nix
            {
              options = {
                privacyApps = nixpkgs.lib.mkOption {
                  type = nixpkgs.lib.types.bool;
                  default = false;
                };
              };
              config.privacyApps = privacyApps;
              config.system.primaryUser = primaryUser;
            }
          ]
          ++ extraModules;
        };
    in
    {
      darwinConfigurations = {
        # M5 Pro
        "basnijholt-macbook-pro-m5" = mkDarwin {
          privacyApps = true;
          primaryUser = "basnijholt";
          extraModules = [
            {
              networking.hostName = "basnijholt-macbook-pro-m5";
              networking.computerName = "basnijholt-macbook-pro-m5";
              local.t3code = {
                enable = true;
                host = "100.64.0.39";
              };
              local.paseo = {
                enable = true;
                host = "100.64.0.39";
              };
            }
          ];
        };
        # M5 Max
        "basnijholt-macbook-pro-m5-2" = mkDarwin {
          privacyApps = false;
          primaryUser = "basnijholt";
          extraModules = [
            ./always-on.nix
            {
              networking.hostName = "basnijholt-macbook-pro-m5-2";
              networking.computerName = "basnijholt-macbook-pro-m5-2";
              local.t3code = {
                enable = true;
                host = "100.64.0.17";
              };
            }
          ];
        };
        # M2 Pro that stays on with its lid closed, used remotely
        "basnijholt-macbook-pro-m2" = mkDarwin {
          privacyApps = true;
          primaryUser = "basnijholt";
          extraModules = [
            ./always-on.nix
            ./imessage.nix
            {
              # Pinned so a name collision on the LAN can't turn it into "-3",
              # which breaks darwin-rebuild's LocalHostName flake lookup
              networking.hostName = "basnijholt-macbook-pro-m2";
              networking.computerName = "basnijholt-macbook-pro-m2";
              local.t3code = {
                enable = true;
                host = "100.64.0.27";
              };
              local.paseo = {
                enable = true;
                host = "100.64.0.27";
              };
            }
          ];
        };
      };
    };
}
