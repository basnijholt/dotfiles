# Nixpkgs configuration (allowUnfree, etc.)
{ lib, ... }:

{
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = lib.mkAfter [
    (
      final: prev:
        lib.optionalAttrs (prev ? ookla-speedtest)
          {
            ookla-speedtest = prev.ookla-speedtest.overrideAttrs (_old: {
              unpackPhase = ''
                runHook preUnpack
                mkdir source
                tar -xzf "$src" -C source
                sourceRoot=source
                runHook postUnpack
              '';
            });
          }
        // lib.optionalAttrs (prev ? terraform) {
          terraform = prev.terraform.overrideAttrs (_old: {
            doCheck = false;
          });
        }
        // lib.optionalAttrs (prev ? raspberrypiWirelessFirmware_20251008) {
          raspberrypiWirelessFirmware_20251008 = prev.raspberrypiWirelessFirmware_20251008.overrideAttrs (old: {
            unpackPhase = ''
              runHook preUnpack
              mkdir source
              for src in $srcs; do
                name=$(basename "$src")
                cp -R "$src" "source/''${name#*-}"
              done
              chmod -R u+w source
              sourceRoot=source
              runHook postUnpack
            '';
            installPhase = builtins.replaceStrings
              [ "$NIX_BUILD_TOP/" "cp -rv " ]
              [ "./" "cp -rv --no-preserve=mode " ]
              old.installPhase;
          });
        }
        // lib.optionalAttrs (prev ? raspberrypifw_20250915) {
          raspberrypifw_20250915 = prev.raspberrypifw_20250915.overrideAttrs (_old: {
            src = prev.fetchFromGitHub {
              owner = "raspberrypi";
              repo = "firmware";
              rev = "1.20250915";
              hash = "sha256-0vqMlXZrGlEToUZT466oaXx2jbpEm4XTUYQnAmCD2DY=";
            };
          });
        }
    )
  ];
}
