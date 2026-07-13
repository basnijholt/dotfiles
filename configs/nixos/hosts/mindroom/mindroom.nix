{ ... }:
{
  services.git-repo-checkouts = {
    enable = true;
    repositories.mindroom = {
      path = "/srv/mindroom";
      url = "https://github.com/mindroom-ai/mindroom.git";
      branch = "main";
      user = "basnijholt";
      group = "users";
      updateWhenClean = true;
    };
  };
}
