{ ... }:
{
  services.git-repo-checkouts = {
    enable = true;
    repositories.openclaw = {
      path = "/srv/openclaw";
      # Track Bas's fork on GitHub from /srv so rebuilds stay pure and the
      # managed checkout matches the current message-enrich workstream.
      url = "https://github.com/basnijholt/openclaw.git";
      branch = "message-enrich";
      user = "basnijholt";
      group = "users";
      hardResetWhenDiverged = true;
    };
  };
}
