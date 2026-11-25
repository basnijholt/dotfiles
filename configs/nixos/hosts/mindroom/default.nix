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

  # --- Resource Isolation ---
  # Isolate agent shell subprocesses from mindroom-chat (and from host pc) so
  # parallel pytest/tsc/vitest/eslint runs hit cgroup limits inside
  # mindroom-shells.slice instead of wedging mindroom or pc.
  #
  # Matching host-side Incus config on pc (not managed by NixOS) — merge into
  # `raw.lxc` with `incus config edit mindroom` so existing `raw.lxc` lines are
  # preserved:
  #   raw.lxc: |
  #     lxc.cgroup2.memory.min = 6G
  #     lxc.cgroup2.memory.low = 8G
  #     lxc.cgroup2.memory.max = 44G
  #     lxc.cgroup2.memory.swap.max = 8G
  # Setting memory.max and memory.swap.max explicitly in raw.lxc (rather than
  # Incus's limits.memory, which sets memory.swap.max = 0) keeps a swap budget
  # (>= mindroom-shells.slice's 4G) while capping the container below pc's
  # 62 GiB RAM; memory.min/memory.low let mindroom-chat's MemoryMin/MemoryLow
  # take effect.

  # Delegate cgroup v2 controllers so basnijholt's user manager (uid 1000) can
  # enforce CPU, cpuset, IO, memory, and pids limits on mindroom-shells.slice.
  systemd.services."user@1000" = {
    overrideStrategy = "asDropin";
    restartIfChanged = false;
    serviceConfig.Delegate = "cpu cpuset io memory pids";
  };

  # Cap agent shell subprocesses; leaves threads 0-3 untouched for mindroom-chat
  # and pc interactivity while giving shells 20 threads.
  systemd.user.slices.mindroom-shells = {
    description = "MindRoom agent shell subprocesses";
    sliceConfig = {
      MemoryHigh = "28G";
      MemoryMax = "34G";
      MemorySwapMax = "4G";
      AllowedCPUs = "4-23";
      CPUWeight = 1;
      IOWeight = 1;
    };
  };

  # Cgroup v2 memory.min and memory.low are bounded by ancestor values, so
  # propagate them onto system.slice for mindroom-chat.service below.
  systemd.slices.system = {
    overrideStrategy = "asDropin";
    sliceConfig = {
      MemoryMin = "4G";
      MemoryLow = "6G";
    };
  };

  # Protect mindroom-chat from agent shell pressure and point its shell runner
  # at basnijholt's user manager and mindroom-shells.slice. Negative
  # OOMScoreAdjust is ignored in an unprivileged Incus container, so OOM
  # protection relies on mindroom-shells.slice's MemoryMax + host earlyoom's --avoid.
  systemd.services.mindroom-chat = {
    after = [ "user@1000.service" ];
    wants = [ "user@1000.service" ];
    serviceConfig = {
      Environment = [
        "XDG_RUNTIME_DIR=/run/user/1000"
        "MINDROOM_SHELL_SYSTEMD_SLICE=mindroom-shells.slice"
      ];
      MemoryMin = "4G";
      MemoryLow = "6G";
      CPUWeight = 1000;
      IOWeight = 1000;
    };
  };

  # libstdc++.so.6 for Python packages (numpy, qdrant-client, chromadb)
  # that link against it. Without this, uv run / pytest fail with import errors.
  environment.variables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
}
