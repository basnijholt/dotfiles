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

  # rclone config file (HTTP to home server via Tailscale)
  environment.etc."rclone/rclone.conf".text = ''
    [${rcloneRemote}]
    type = http
    url = http://${mediaServerIp}:8899
  '';

  # --- rclone VFS mount service ---
  systemd.services.rclone-media = {
    description = "rclone VFS mount for media";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mediaMount}";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount ${rcloneRemote}: ${mediaMount} \
          --config /etc/rclone/rclone.conf \
          --vfs-cache-mode full \
          --vfs-read-ahead 512M \
          --vfs-cache-max-size 5G \
          --vfs-cache-max-age 48h \
          --buffer-size 256M \
          --vfs-read-chunk-size 64M \
          --vfs-read-chunk-size-limit 512M \
          --vfs-fast-fingerprint \
          --no-modtime \
          --no-checksum \
          --transfers 4 \
          --dir-cache-time 72h \
          --poll-interval 0 \
          --read-only \
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
