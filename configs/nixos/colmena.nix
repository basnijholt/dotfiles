{
  pkgs,
  aarch64Pkgs,
  piPkgs,
  commonModules,
  home-manager,
  home-manager-pi,
  disko,
  ragenix,
  zfs-unlock,
  nixos-raspberrypi,
}:

let
  deploymentModule =
    {
      targetHost,
      tags,
      allowLocalDeployment ? false,
    }:
    {
      deployment = {
        inherit targetHost tags allowLocalDeployment;
        targetUser = "basnijholt";
        privilegeEscalationCommand = [
          "sudo"
          "-H"
          "-n"
          "--"
        ];
      };
    };

  node = modules: deployment: {
    imports = commonModules home-manager ++ modules ++ [ deployment ];
  };

  armNode = modules: deployment: {
    imports = commonModules home-manager ++ modules ++ [ deployment ];
  };

  piNode = piModule: modules: deployment: {
    imports = [ piModule ] ++ commonModules home-manager-pi ++ modules ++ [ deployment ];
  };
in
{
  meta = {
    name = "bas-nixos";
    description = "Bas's NixOS hosts";
    nixpkgs = pkgs;
    nodeNixpkgs = {
      hetzner = aarch64Pkgs;
      hetzner-matrix = aarch64Pkgs;
      pi4 = piPkgs;
    };
    nodeSpecialArgs.pi4 = { inherit nixos-raspberrypi; };
  };

  pc =
    node
      [
        disko.nixosModules.disko
        ./hosts/pc/disko.nix
        ./hosts/pc/default.nix
        ./hosts/pc/hardware-configuration.nix
      ]
      (deploymentModule {
        targetHost = "pc";
        tags = [
          "physical"
          "home"
        ];
        allowLocalDeployment = true;
      });

  nuc =
    node
      [
        disko.nixosModules.disko
        ./hosts/nuc/disko.nix
        ./hosts/nuc/default.nix
        ./hosts/nuc/hardware-configuration.nix
      ]
      (deploymentModule {
        targetHost = "nuc";
        tags = [
          "physical"
          "home"
        ];
      });

  hp =
    node
      [
        disko.nixosModules.disko
        ./hosts/hp/disko.nix
        ./hosts/hp/default.nix
        ./hosts/hp/hardware-configuration.nix
      ]
      (deploymentModule {
        targetHost = "hp";
        tags = [
          "physical"
          "home"
        ];
      });

  nas =
    node
      [
        disko.nixosModules.disko
        zfs-unlock.nixosModules.receiver
        ./hosts/nas/disko.nix
        ./hosts/nas/default.nix
        ./hosts/nas/hardware-configuration.nix
      ]
      (deploymentModule {
        targetHost = "nas";
        tags = [
          "physical"
          "home"
          "storage"
        ];
      });

  pi4 =
    piNode nixos-raspberrypi.nixosModules.raspberry-pi-4.base
      [
        disko.nixosModules.disko
        zfs-unlock.nixosModules.client
        ./hosts/pi4/disko.nix
        ./hosts/pi4/default.nix
        ./hosts/pi4/hardware-configuration.nix
      ]
      (deploymentModule {
        targetHost = "pi4";
        tags = [
          "physical"
          "home"
          "arm"
        ];
      });

  docker-lxc =
    node
      [
        ./hosts/docker-lxc/default.nix
      ]
      (deploymentModule {
        targetHost = "docker";
        tags = [
          "container"
          "home"
        ];
      });

  nix-cache =
    node
      [
        ./hosts/nix-cache/default.nix
      ]
      (deploymentModule {
        targetHost = "nix-cache";
        tags = [
          "container"
          "home"
          "cache"
        ];
      });

  hetzner =
    armNode
      [
        disko.nixosModules.disko
        ./hosts/hetzner/disko.nix
        ./hosts/hetzner/default.nix
        ./hosts/hetzner/hardware-configuration.nix
      ]
      (deploymentModule {
        targetHost = "nixos-hetzner";
        tags = [
          "cloud"
          "arm"
        ];
      });

  hetzner-matrix =
    armNode
      [
        ragenix.nixosModules.default
        disko.nixosModules.disko
        ./hosts/hetzner-matrix/disko.nix
        ./hosts/hetzner-matrix/default.nix
        ./hosts/hetzner-matrix/hardware-configuration.nix
      ]
      (deploymentModule {
        targetHost = "hetzner-matrix";
        tags = [
          "cloud"
          "arm"
          "mindroom"
        ];
      });
}
