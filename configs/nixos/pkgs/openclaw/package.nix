{
  lib,
  stdenvNoCC,
  fetchgit,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_22,
  gitMinimal,
  makeWrapper,
  rolldown,
  openclawSrc ? fetchgit {
    url = "https://github.com/basnijholt/openclaw.git";
    rev = "8245cd260f85a6e772c077bbe95497bf1f9e8cc4";
    hash = "sha256-hiFhf2bn3f5+AluxfU65I89i/ovPN9S7axNHW8VjTkM=";
  },
  pnpmDepsHash,
  version ? (lib.importJSON "${openclawSrc}/package.json").version,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openclaw";
  inherit version;
  src = openclawSrc;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = pnpmDepsHash;
    nativeBuildInputs = [ gitMinimal ];
  };

  buildInputs = [ rolldown ];

  postPatch = ''
    # Avoid pnpm trying to self-manage the version during pnpmConfigHook.
    sed -i '/"packageManager": "pnpm@.*",/d' package.json
  '';

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs_22
    makeWrapper
  ];

  preBuild = ''
    rm -rf node_modules/rolldown node_modules/@rolldown/pluginutils
    mkdir -p node_modules/@rolldown
    cp -r ${rolldown}/lib/node_modules/rolldown node_modules/rolldown
    cp -r ${rolldown}/lib/node_modules/@rolldown/pluginutils node_modules/@rolldown/pluginutils
    chmod -R u+w node_modules/rolldown node_modules/@rolldown/pluginutils
  '';

  buildPhase = ''
    runHook preBuild

    pnpm install --frozen-lockfile
    pnpm build
    pnpm ui:build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    libdir=$out/lib/openclaw
    mkdir -p $libdir $out/bin

    cp --reflink=auto -r package.json dist node_modules $libdir/
    cp --reflink=auto -r assets docs skills patches extensions $libdir/ 2>/dev/null || true

    rm -f $libdir/node_modules/.pnpm/node_modules/clawdbot \
      $libdir/node_modules/.pnpm/node_modules/moltbot \
      $libdir/node_modules/.pnpm/node_modules/openclaw-control-ui

    makeWrapper ${lib.getExe nodejs_22} $out/bin/openclaw \
      --add-flags "$libdir/dist/index.js" \
      --set NODE_PATH "$libdir/node_modules"
    ln -s $out/bin/openclaw $out/bin/moltbot
    ln -s $out/bin/openclaw $out/bin/clawdbot

    runHook postInstall
  '';

  meta = with lib; {
    description = "Self-hosted AI assistant/agent";
    homepage = "https://openclaw.ai";
    license = licenses.mit;
    mainProgram = "openclaw";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
