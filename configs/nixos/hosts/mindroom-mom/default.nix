# MindRoom companion container for mom. MindRoom only — no OpenClaw.
# Deploys via comin (GitOps) like most hosts; unlike mindroom-spouse this
# container is hands-off.
{ ... }:

{
  imports = [
    ../../optional/mindroom-companion.nix
    ./networking.nix
  ];
}
