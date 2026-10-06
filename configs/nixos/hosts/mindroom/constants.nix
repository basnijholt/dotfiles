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
  tuwunelVersion = "v1.9.1-mindroom.16";
  tuwunelArchiveHash = "sha256-IVPcJv8Uo5L5herc+sKGZCTFezxSoy5BCUZBGsf7LMI=";
}
