let
  # This LXC currently advertises and serves the lab Matrix/app domain. Traefik
  # fronts the public *.lab.mindroom.chat names and forwards them here.
  siteDomain = "mindroom.lab.mindroom.chat";
in
{
  inherit siteDomain;
  publicBaseDomain = "lab.mindroom.chat";
  publicSiteDomain = siteDomain;
  publicCinnyDomain = "chat.lab.mindroom.chat";
  tuwunelVersion = "v1.9.3-mindroom.1";
  tuwunelArchiveHash = "sha256-chXru1ObjCPW9qqQg5nebOiPE1h5PaWwdjjgCQPVBdg=";
}
