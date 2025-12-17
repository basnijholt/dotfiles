# GitOps continuous deployment with comin
{ config, ... }:

{
  services.comin = {
    enable = true;
    remotes = [{
      name = "origin";
      url = "https://github.com/basnijholt/dotfiles.git";
      branches.main.name = "main";
    }];
    repositorySubdir = "configs/nixos";
    hostname = config.networking.hostName;
  };
}
