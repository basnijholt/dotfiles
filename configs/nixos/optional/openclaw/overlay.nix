final: _prev:
let
  openclaw = final.callPackage ../../pkgs/openclaw/package.nix {
    pnpmDepsHash = "sha256-CqudeRT7QT7KslnfPWNFWXvGy2U9AbbahoJJYyUyapU=";
  };
in
{
  inherit openclaw;
  openclaw-gateway = openclaw;
}
