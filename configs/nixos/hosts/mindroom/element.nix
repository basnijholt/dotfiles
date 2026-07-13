{ ... }:
{
  services.git-repo-checkouts = {
    enable = true;
    repositories.element = {
      path = "/srv/mindroom-element";
      url = "https://github.com/mindroom-ai/mindroom-element.git";
      branch = "develop";
      user = "basnijholt";
      group = "users";
      updateWhenClean = true;
    };
  };
}
