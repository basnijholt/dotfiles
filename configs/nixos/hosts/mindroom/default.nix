{ lib, pkgs, ... }:

{
  imports = [
    # Optional modules (Tier 2)
    # Note: mindroom is a lightweight development container
    ../../optional/git-repo-checkouts.nix
    ../../optional/virtualization.nix
    ../../optional/mindroom-runtime-services.nix
    ../../optional/agent-env.nix

    # Host-specific modules (Tier 3)
    ./networking.nix
    ./secrets-config.nix
    ./mindroom.nix
    ./cinny.nix
    ./element.nix
    ./tuwunel.nix  # Local Matrix homeserver (MindRoom Tuwunel fork)
    ./caddy.nix
    ../../optional/openclaw/services.nix
  ];

  # Allow basnijholt passwordless sudo (for mindroom agent)
  security.sudo.extraRules = [{
    users = [ "basnijholt" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # signal-cli for OpenClaw Signal channel
  environment.systemPackages = [ pkgs.signal-cli pkgs.ffmpeg-headless pkgs.chromium ];

  nixpkgs.config.permittedInsecurePackages = lib.mkAfter [
    "openclaw-2026.6.11"
  ];

  # libstdc++.so.6 for Python packages (numpy, qdrant-client, chromadb)
  # that link against it. Without this, uv run / pytest fail with import errors.
  environment.variables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";

  # Root CA of the Agent Vault instance at https://agent-vault.lab.nijho.lt
  # (docker-lxc host). The agent-vault-bridge MindRoom plugin routes agent
  # GitHub calls through its MITM proxy; this trust anchor validates the
  # re-signed upstream certs. The proxy-role token lives imperatively at
  # ~basnijholt/.config/agent-vault/proxy-token (mode 0600).
  # Re-fetch after a vault re-install: agent-vault ca fetch --address https://agent-vault.lab.nijho.lt
  environment.etc."ssl/agent-vault-ca.pem".text = ''
    -----BEGIN CERTIFICATE-----
    MIIBfDCCASKgAwIBAgIQKc3Oof3kFBhBe6/UIvnVnTAKBggqhkjOPQQDAjAeMRww
    GgYDVQQDExNBZ2VudCBWYXVsdCBSb290IENBMB4XDTI2MDcwMjA1MjIxOFoXDTM2
    MDYyOTA1MjcxOFowHjEcMBoGA1UEAxMTQWdlbnQgVmF1bHQgUm9vdCBDQTBZMBMG
    ByqGSM49AgEGCCqGSM49AwEHA0IABOhI85qal9SYv6XGKm9ZRC5tWBvA3Brgo8ms
    qVFNCKvVvHcilvlSCQ0yS8+gZXf4fnyk71cdSLfhPXcWrHxSpTqjQjBAMA4GA1Ud
    DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBR1d9giMX6+wl0H
    eC3eu2PU6xSUYDAKBggqhkjOPQQDAgNIADBFAiEA/P/yeh4dQCQquh2Yxr6HXhZd
    qDWm4PhtNHWQ3gi/HD0CIGVBrc6VqYPWLYC5JGEDPeCfcVL4uu/0Lvc61CmbLPm4
    -----END CERTIFICATE-----
  '';
}
