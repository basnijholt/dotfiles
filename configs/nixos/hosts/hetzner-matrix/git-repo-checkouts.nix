{ lib, pkgs, config, ... }:

let
  cfg = config.services.git-repo-checkouts;
in
{
  options.services.git-repo-checkouts = {
    enable = lib.mkEnableOption "managed Git checkouts for host runtime repositories";

    repositories = lib.mkOption {
      default = { };
      description = "Named runtime Git checkouts that should exist on the host.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Absolute path for the checkout.";
          };

          url = lib.mkOption {
            type = lib.types.str;
            description = "Git remote URL.";
          };

          branch = lib.mkOption {
            type = lib.types.str;
            description = "Branch to track.";
          };

          user = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Service user used for clone/fetch/checkout/pull.";
          };

          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Service group used for clone/fetch/checkout/pull.";
          };

          dirMode = lib.mkOption {
            type = lib.types.str;
            default = "0755";
            description = "Mode for the checkout directory created via tmpfiles.";
          };

          updateWhenClean = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Run ff-only pull when the working tree has no local changes.";
          };

          hardResetWhenDiverged = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              If true and the working tree is clean, reset hard to origin/<branch>
              when local and remote branch histories diverge.
            '';
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules =
      lib.mapAttrsToList
        (_name: repo: "d ${repo.path} ${repo.dirMode} ${repo.user} ${repo.group} -")
        cfg.repositories;

    systemd.services =
      lib.mapAttrs'
        (
          name: repo:
          lib.nameValuePair "git-checkout-${name}" {
            description = "Ensure runtime git checkout: ${name}";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            path = with pkgs; [ bash coreutils git ];
            serviceConfig = {
              Type = "oneshot";
              User = repo.user;
              Group = repo.group;
            };
            script = ''
              set -euo pipefail

              repo_path=${lib.escapeShellArg repo.path}
              repo_url=${lib.escapeShellArg repo.url}
              repo_branch=${lib.escapeShellArg repo.branch}
              update_when_clean=${if repo.updateWhenClean then "1" else "0"}
              hard_reset_when_diverged=${if repo.hardResetWhenDiverged then "1" else "0"}

              if [ ! -d "$repo_path/.git" ]; then
                if [ -d "$repo_path" ] && [ -n "$(ls -A "$repo_path")" ]; then
                  echo "Refusing to clone into non-empty non-git directory: $repo_path" >&2
                  exit 1
                fi
                mkdir -p "$repo_path"
                git clone --origin origin --branch "$repo_branch" "$repo_url" "$repo_path"
                exit 0
              fi

              git -C "$repo_path" remote set-url origin "$repo_url"
              git -C "$repo_path" fetch --prune origin "$repo_branch"

              if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$repo_branch"; then
                git -C "$repo_path" checkout "$repo_branch"
              else
                git -C "$repo_path" checkout -b "$repo_branch" --track "origin/$repo_branch"
              fi

              if [ "$update_when_clean" = "1" ]; then
                if [ -n "$(git -C "$repo_path" status --porcelain)" ]; then
                  echo "Working tree has local changes; skipping pull for $repo_path."
                else
                  local_head="$(git -C "$repo_path" rev-parse HEAD)"
                  remote_head="$(git -C "$repo_path" rev-parse "origin/$repo_branch")"

                  if [ "$local_head" = "$remote_head" ]; then
                    exit 0
                  fi

                  if git -C "$repo_path" merge-base --is-ancestor "$local_head" "$remote_head"; then
                    git -C "$repo_path" pull --ff-only origin "$repo_branch"
                  elif [ "$hard_reset_when_diverged" = "1" ]; then
                    echo "Branch diverged; resetting $repo_path to origin/$repo_branch."
                    git -C "$repo_path" reset --hard "origin/$repo_branch"
                  else
                    echo "Branch diverged for $repo_path; refusing to update without hardResetWhenDiverged." >&2
                    exit 1
                  fi
                fi
              fi
            '';
          }
        )
        cfg.repositories;
  };
}
