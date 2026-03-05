{
  lib,
  stdenvNoCC,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_22,
  makeWrapper,
  src,
  pnpmDepsHash,
  version ? (lib.importJSON "${src}/package.json").version,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openclaw";
  inherit version src;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = pnpmDepsHash;
  };

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs_22
    makeWrapper
  ];

  buildPhase = ''
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
