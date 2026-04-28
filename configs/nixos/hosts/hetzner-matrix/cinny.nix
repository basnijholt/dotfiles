{ lib, pkgs, ... }:

let
  constants = import ./constants.nix;
  inherit (constants) cinnyCheckoutPath cinnyPublishedPath cinnyCurrentPath;

  publishCinny = pkgs.writeShellApplication {
    name = "mindroom-publish-cinny";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nodejs
      rsync
    ];
    text = ''
      set -euo pipefail

      checkout=${lib.escapeShellArg cinnyCheckoutPath}
      publish_root=${lib.escapeShellArg cinnyPublishedPath}
      current_link=${lib.escapeShellArg cinnyCurrentPath}
      releases_dir="$publish_root/releases"
      ref="''${1:-HEAD}"

      if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
        cat <<'EOF'
Usage: mindroom-publish-cinny [git-ref]

Build the requested Cinny ref in a detached worktree, validate the generated
site, then atomically switch the live publish symlink. If no ref is provided,
HEAD from /var/www/cinny is used.
EOF
        exit 0
      fi

      ${pkgs.git}/bin/git -C "$checkout" fetch --prune origin --tags

      short_sha="$(${pkgs.git}/bin/git -C "$checkout" rev-parse --short "$ref")"
      ref_safe="$(printf '%s' "$ref" | tr '/:@ ' '____')"
      timestamp="$(date +%Y%m%d-%H%M%S)"
      worktree="$(mktemp -d /tmp/cinny-publish-worktree.XXXXXX)"
      release_dir="$releases_dir/$timestamp-$ref_safe-$short_sha"
      next_link="$publish_root/.current.new"

      cleanup() {
        rm -f "$next_link"
        if [ -d "$worktree" ]; then
          ${pkgs.git}/bin/git -C "$checkout" worktree remove --force "$worktree" >/dev/null 2>&1 || rm -rf "$worktree"
        fi
      }
      trap cleanup EXIT

      mkdir -p "$releases_dir"
      ${pkgs.git}/bin/git -C "$checkout" worktree add --detach "$worktree" "$ref"

      cd "$worktree"
      if [ -n "''${NODE_OPTIONS:-}" ]; then
        export NODE_OPTIONS="$NODE_OPTIONS --max-old-space-size=4096"
      else
        export NODE_OPTIONS="--max-old-space-size=4096"
      fi

      npm ci
      npm run build

      test -s dist/index.html
      test -d dist/assets
      test -s dist/runtime-config.js

      mkdir -p "$release_dir"
      rsync -a --delete dist/ "$release_dir/"

      ln -s "$release_dir" "$next_link"
      mv -Tf "$next_link" "$current_link"

      echo "Published Cinny ref $ref ($short_sha) to $release_dir"
      echo "Live root now points at $current_link"
    '';
  };
in
{
  # MindRoom Cinny fork checkout is Nix-managed. Published static assets live
  # outside the checkout so a failed build cannot blank the live site.
  # Build/update remains operator-triggered via `mindroom-publish-cinny`.
  services.git-repo-checkouts = {
    enable = true;
    repositories.cinny = {
      path = cinnyCheckoutPath;
      url = "https://github.com/mindroom-ai/mindroom-cinny.git";
      branch = "dev";
      user = "basnijholt";
      group = "users";
      updateWhenClean = true;
      hardResetWhenDiverged = true;
    };
  };

  environment.systemPackages = [ publishCinny ];

  systemd.tmpfiles.rules = [
    "d ${cinnyPublishedPath} 0755 basnijholt users -"
    "d ${cinnyPublishedPath}/releases 0755 basnijholt users -"
  ];

  system.activationScripts.cinnyBootstrapPublishedRoot.text = ''
    publish_root=${lib.escapeShellArg cinnyPublishedPath}
    current_link=${lib.escapeShellArg cinnyCurrentPath}
    checkout_dist=${lib.escapeShellArg "${cinnyCheckoutPath}/dist"}
    bootstrap_release="$publish_root/releases/bootstrap-initial"
    next_link="$publish_root/.current.new"

    mkdir -p "$publish_root/releases"

    if [ ! -e "$current_link" ] && [ -f "$checkout_dist/index.html" ]; then
      rm -rf "$bootstrap_release"
      mkdir -p "$bootstrap_release"
      cp -a "$checkout_dist"/. "$bootstrap_release"/
      ln -s "$bootstrap_release" "$next_link"
      mv -Tf "$next_link" "$current_link"
      chown -R basnijholt:users "$publish_root"
      chown -h basnijholt:users "$current_link"
    fi
  '';
}
