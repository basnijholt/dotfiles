{ pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: mindroom runs the MindRoom lab and chat runtimes
    ../../optional/git-repo-checkouts.nix
    ../../optional/virtualization.nix
    ../../optional/mindroom-runtime-services.nix
    ../../optional/agent-env.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./secrets-config.nix
    ./mindroom.nix
    ./mindroom-chat.nix
    ./tuwunel.nix  # Local Matrix homeserver (MindRoom Tuwunel fork)
    ./caddy.nix
  ];

  # Allow basnijholt passwordless sudo (for mindroom agent)
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # MindRoom runtime dependencies
  environment.systemPackages = [ pkgs.ffmpeg-headless pkgs.chromium ];

  # mindroom-chat workers run the locally built mindroom:dev-docs image (on
  # top of mindroom:dev), which exists in no registry. The common weekly
  # `docker system prune --all` deletes every image without a container, so
  # it wiped both whenever no worker was running (2026-10-26, 2026-11-02) and
  # every worker tool call then failed with "pull access denied". Prune only
  # dangling images here; rebuild leftovers still go.
  virtualisation.docker.autoPrune.flags = [ ];

  # Agents' nix-shell and nix develop calls make nix-daemon build and evaluate
  # for them. At the default policy those workers took about a core from the
  # mindroom-chat event loop under load (2026-11-17). SCHED_IDLE lets them run
  # only on CPU nothing else wants, like the agents' own shell jobs (mindroom#4092).
  nix.daemonCPUSchedPolicy = "idle";

  # libstdc++.so.6 for Python packages (numpy, qdrant-client, chromadb)
  # that link against it. Without this, uv run / pytest fail with import errors.
  environment.variables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
}
