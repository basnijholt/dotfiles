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
  tuwunelVersion = "v2.0.0-mindroom.5";
  tuwunelArchiveHash = "sha256-M5MWfOv2wzSUoNprWPpyvSrLDToIM3RIN3V6rA61y6Q=";
}
