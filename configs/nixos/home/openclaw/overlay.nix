{ openclaw-patched }:
final: _prev:
let
  openclaw = final.callPackage ../../pkgs/openclaw/package.nix {
    src = openclaw-patched;
    pnpmDepsHash = "sha256-TuxMbWgX1iOthVGnXBV4PM7Ci2apFV6UHsqRMvohgVY=";
  };
in
{
  inherit openclaw;
  openclaw-gateway = openclaw;
}
