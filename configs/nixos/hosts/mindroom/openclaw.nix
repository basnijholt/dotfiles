{ ... }:
{
  services.git-repo-checkouts = {
    enable = true;
    repositories.openclaw = {
      path = "/srv/openclaw";
      # Mirror the current local OpenClaw fork checkout onto /srv so rebuilds
      # do not depend on an impure flake path in basnijholt's home directory.
      url = "/home/basnijholt/openclaw-src";
      branch = "message-enrich";
      user = "basnijholt";
      group = "users";
      hardResetWhenDiverged = true;
    };
  };
}
