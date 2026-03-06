final: prev:
let
  fork = rec {
    rev = "8245cd260f85a6e772c077bbe95497bf1f9e8cc4";
    src = final.fetchgit {
      url = "https://github.com/basnijholt/openclaw.git";
      inherit rev;
      hash = "sha256-hiFhf2bn3f5+AluxfU65I89i/ovPN9S7axNHW8VjTkM=";
    };
    version = (final.lib.importJSON "${src}/package.json").version;
    pnpmDepsHash = "sha256-CqudeRT7QT7KslnfPWNFWXvGy2U9AbbahoJJYyUyapU=";
  };
  openclaw = prev.openclaw.overrideAttrs (old: {
    inherit (fork) src version pnpmDepsHash;
    pnpmDeps = final.fetchPnpmDeps {
      pname = old.pname;
      inherit (fork) src version pnpmDepsHash;
      pnpm = final.pnpm_10;
      fetcherVersion = 3;
      hash = fork.pnpmDepsHash;
      nativeBuildInputs = [ final.gitMinimal ];
    };
    postPatch = (old.postPatch or "") + ''
      # Avoid pnpm trying to self-manage the version during pnpmConfigHook.
      sed -i '/"packageManager": "pnpm@.*",/d' package.json
    '';
    meta = old.meta // {
      description = "Self-hosted AI assistant/agent";
      changelog = "https://github.com/basnijholt/openclaw/commit/${fork.rev}";
      # Upstream marks OpenClaw insecure; keep the local fork evaluable.
      knownVulnerabilities = [ ];
    };
  });
in
{
  inherit openclaw;
  openclaw-gateway = openclaw;
}
