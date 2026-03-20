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
  publicElementDomain = "element.lab.mindroom.chat";
  tuwunelVersion = "v1.5.1-mindroom.5";
  tuwunelArchiveHash = "sha256-lp131zE5nUimONx4G/VwgvHMy+OuCIXWcL1Wwm6EwL8=";
}
