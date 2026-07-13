{ ... }:
{
  services.git-repo-checkouts = {
    enable = true;
    repositories.cinny = {
      path = "/var/www/cinny";
      url = "https://github.com/mindroom-ai/mindroom-chat.git";
      branch = "dev";
      user = "basnijholt";
      group = "users";
      updateWhenClean = true;
      hardResetWhenDiverged = true;
    };
  };
}
