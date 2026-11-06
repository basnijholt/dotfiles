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
  tuwunelVersion = "v1.9.4-mindroom.29";
  tuwunelArchiveHash = "sha256-0IZkeDOmoZ3YBVA6yzMuyFeYvCAz6KKeX21M6w9KB+U=";
}
