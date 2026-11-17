let
  # This LXC currently advertises and serves the lab Matrix/app domain. Traefik
  # fronts the public *.lab.mindroom.chat names and forwards them here.
  siteDomain = "mindroom.lab.mindroom.chat";
in
{
  inherit siteDomain;
  publicBaseDomain = "lab.mindroom.chat";
  publicSiteDomain = siteDomain;
  publicChatDomain = "chat.lab.mindroom.chat";
  # Releases of the MindRoom Chat static build and the `current` symlink Caddy serves.
  chatPublishedPath = "/var/www/mindroom-chat";
  tuwunelVersion = "v1.9.4-mindroom.47";
  tuwunelArchiveHash = "sha256-1U1OYgtjoJMVXzZivjgwMKpN40K9imsBRAcLCnSCKiQ=";
}
