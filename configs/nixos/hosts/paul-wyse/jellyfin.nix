# Local Jellyfin media server with rclone VFS mount
#
# Media is mounted from home server via rclone SFTP over Tailscale.
# VFS caching buffers content locally to handle network latency.
{ config, pkgs, lib, ... }:

let
  mediaMount = "/mnt/media";
  rcloneRemote = "home-media";
  # Tailscale IP of docker-lxc where media is stored
  mediaServerIp = "100.64.0.28";
in
{
  # --- rclone configuration ---
  environment.systemPackages = [ pkgs.rclone ];

  # rclone config file (SFTP to home server via Tailscale)
  environment.etc."rclone/rclone.conf".text = ''
    [${rcloneRemote}]
    type = sftp
    host = ${mediaServerIp}
    user = basnijholt
    key_file = /root/.ssh/id_ed25519
    shell_type = unix
  '';

  # --- rclone VFS mount service ---
  systemd.services.rclone-media = {
    description = "rclone VFS mount for media";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mediaMount}";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount ${rcloneRemote}:/mnt/tank/media ${mediaMount} \
          --config /etc/rclone/rclone.conf \
          --vfs-cache-mode full \
          --vfs-read-ahead 256M \
          --vfs-cache-max-size 20G \
          --vfs-cache-max-age 24h \
          --buffer-size 128M \
          --dir-cache-time 1h \
          --poll-interval 1m \
          --allow-other \
          --uid 1000 \
          --gid 1000
      '';
      ExecStop = "${pkgs.fuse}/bin/fusermount -uz ${mediaMount}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # Allow FUSE mounts with allow-other
  programs.fuse.userAllowOther = true;

  # --- Local Jellyfin ---
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # Make Jellyfin wait for media mount
  systemd.services.jellyfin = {
    after = [ "rclone-media.service" ];
    wants = [ "rclone-media.service" ];
  };
}
