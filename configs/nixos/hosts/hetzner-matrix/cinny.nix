{ ... }:

{
  # MindRoom Cinny fork served as static files from /var/www/cinny/dist.
  # Checkout bootstrap/sync is Nix-managed; build/update is still manual.
  services.git-repo-checkouts = {
    enable = true;
    repositories.cinny = {
      path = "/var/www/cinny";
      url = "https://github.com/mindroom-ai/mindroom-cinny.git";
      branch = "dev";
      user = "basnijholt";
      group = "users";
      updateWhenClean = true;
      hardResetWhenDiverged = true;
    };
  };
}
