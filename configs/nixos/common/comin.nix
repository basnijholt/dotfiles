# GitOps continuous deployment with comin
{ config, pkgs, ... }:

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

  # Fix diverged history on comin start (e.g., after force-push)
  systemd.services.comin.preStart = ''
    REPO="/var/lib/comin/repository"
    if [ -d "$REPO/.git" ]; then
      ${pkgs.git}/bin/git -C "$REPO" fetch origin
      ${pkgs.git}/bin/git -C "$REPO" reset --hard origin/main
    fi
  '';
}
