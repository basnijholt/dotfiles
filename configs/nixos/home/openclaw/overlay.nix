{ openclaw-patched }:
final: _prev:
let
  openclaw = final.callPackage ../../pkgs/openclaw/package.nix {
    src = openclaw-patched;
    pnpmDepsHash = "sha256-CqudeRT7QT7KslnfPWNFWXvGy2U9AbbahoJJYyUyapU=";
  };
in
{
  inherit openclaw;
  openclaw-gateway = openclaw;
}
