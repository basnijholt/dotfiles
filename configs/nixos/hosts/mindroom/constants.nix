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
  tuwunelVersion = "v1.8.0-mindroom.3";
  tuwunelArchiveHash = "sha256-uDudIVa0CHW9ZMYcSz1xuEPT3QCRgUainCNGyrTJXPs=";
}
