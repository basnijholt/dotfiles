# PC-specific package overrides (CUDA, custom packages)
# Note: allowUnfree is set in common/nixpkgs.nix
{ lib, pkgs, ... }:

{
  # TODO: remove this overlay and the NVIDIA override in nvidia-graphics.nix
  # once nixos-unstable ships a fixed patchelf (NixOS/patchelf#672).
  # patchelf 0.19.2 aborts in shiftFile when addDriverRunpath re-patches CUDA
  # redists, so pin them to 0.15.2 like nixpkgs#575979. The pin turns itself
  # off with a warning once that fix is in our nixpkgs, so a stale pin cannot
  # cost cache.nixos-cuda.org hits.
  nixpkgs.overlays = [
    (final: prev: {
      patchelf_0_15 = prev.patchelf.overrideAttrs (
        finalAttrs: _: {
          version = "0.15.2";
          src = prev.fetchurl {
            url = "https://github.com/NixOS/patchelf/releases/download/${finalAttrs.version}/patchelf-${finalAttrs.version}.tar.bz2";
            hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
          };
        }
      );
      _cuda =
        if lib.functionArgs (import (prev.path + "/pkgs/development/cuda-modules/buildRedist")) ? patchelf then
          lib.warn "nixpkgs#575979 is in nixpkgs: remove the CUDA patchelf pin in hosts/pc/package-overrides.nix" prev._cuda
        else
          prev._cuda.extend (
            _: cudaPrev: {
              extensions = cudaPrev.extensions ++ [
                (_: cudaPackagesPrev: {
                  buildRedist =
                    args:
                    (cudaPackagesPrev.buildRedist args).overrideAttrs (old: {
                      nativeBuildInputs = [ final.patchelf_0_15 ] ++ old.nativeBuildInputs;
                    });
                })
              ];
            }
          );
    })
  ];

  nixpkgs.config = {
    cudaSupport = true;
    # Build CUDA kernels only for the RTX 3090 instead of every supported GPU;
    # this trades cache.nixos-cuda.org hits for ~10x faster local CUDA builds.
    cudaCapabilities = [ "8.6" ];
    packageOverrides = pkgs: {
      ollama =
        (pkgs.ollama.override {
          # Only build for RTX 3090 (sm_86) instead of all 7 default architectures
          cudaArches = [ "sm_86" ];
        }).overrideAttrs
          (
            oldAttrs:
            let
              # Ollama 0.30+ stages llama.cpp from the release's LLAMA_CPP_VERSION
              # during postPatch. Keep this pin aligned with the overridden Ollama
              # version; otherwise Ollama's compatibility patch can fail to apply.
              llamaCppSrc = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b11669";
                hash = "sha256-pEDYgI3AMTU+cekvRX7NNt5wddznydQSNuerswvEpsA=";
              };
            in
            rec {
              version = "0.40.6";
              src = pkgs.fetchFromGitHub {
                owner = "ollama";
                repo = "ollama";
                rev = "v${version}";
                hash = "sha256-t3Asu9lIz8RW7xonHTJsTvtm1IEM6Rwfa0K5JN48Nwo=";
              };
              vendorHash = "sha256-QBwZKRnmLUHQNSx5oqE9AbMINE8PP5TVJncG9nzQryI=";
              # This package only contains integration-tagged tests, so the
              # generic Go test sweep otherwise reports "build constraints
              # exclude all Go files".
              excludedPackages = (oldAttrs.excludedPackages or [ ]) ++ [ "./integration" ];
              postPatch = ''
                substituteInPlace version/version.go \
                  --replace-fail 0.0.0 '${version}'

                rm cmd/launch/*_test.go
                rm -r app

                cp -r ${llamaCppSrc} $TMPDIR/llama-cpp-src
                chmod -R +w $TMPDIR/llama-cpp-src
                (
                  cd $TMPDIR/llama-cpp-src
                  cmake -DPATCH_DIR=$NIX_BUILD_TOP/source/llama/compat \
                    -P $NIX_BUILD_TOP/source/cmake/apply-git-patches.cmake
                )
              '';
            }
          );

      # Override llama-cpp to the latest release with CUDA support.
      llama-cpp =
        (pkgs.llama-cpp.override {
          cudaSupport = true;
          rocmSupport = false;
          metalSupport = false;
          # This package is deployed only on this Ryzen 9 3900X host. Build
          # one Zen 2 backend instead of nixpkgs' portable dispatch bundle.
          cpuArchDynamicDispatch = false;
          # Enable BLAS for optimized CPU layer performance (OpenBLAS)
          # This is crucial for models using split-mode or CPU offloading
          blasSupport = true;
        }).overrideAttrs
          (oldAttrs: rec {
            version = "11756";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-CAfNw9Y75Nch7abIgvOJioEhr157E/vVqlF2qB8Q8Qk=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
            # nixpkgs backports llama.cpp#30034, which this release already has.
            patches = [ ];
            # Requires the test-download-model fixture, which needs network;
            # CTest runs a required fixture even when nixpkgs disables it.
            disabledTests = (oldAttrs.disabledTests or [ ]) ++ [ "test-llama-context-model" ];
            npmRoot = "tools/ui";
            npmDepsHash = "sha256-hqYzdp1FwPhYkBP278fQXgY9NCKB6Q3P6Gko7BfP0m0=";
            # nixpkgs hardcodes the build number and commit of its own
            # release. Report ours in `llama-server --version`, `/props`,
            # and the web UI; flags appended later win in CMake.
            preConfigure = ''
              pushd ${npmRoot}
              LLAMA_BUILD_NUMBER=${version} npm run build
              popd
              cmakeFlagsArray+=("-DLLAMA_BUILD_COMMIT=$(cat COMMIT)")
            '';
            # Target this host explicitly: Zen 2 CPU and RTX 3090 GPU. Using
            # znver2 instead of GGML_NATIVE avoids llama.cpp overriding the
            # explicit CUDA target with a sandbox-time GPU probe.
            cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
              "-DCMAKE_C_FLAGS=-march=znver2"
              "-DCMAKE_CXX_FLAGS=-march=znver2"
              "-DCMAKE_CUDA_ARCHITECTURES=86" # RTX 3090 - needed since sandbox has no GPU
              "-DLLAMA_BUILD_NUMBER=${version}"
            ];
          });

      # whisper-cpp builds on llama-cpp's ggml. The llama-cpp override above
      # drops GGML_BACKEND_DL, so linking against it needs libcuda.so.1, which
      # the sandbox lacks. Only ffmpeg-full uses whisper-cpp here, so use the
      # cached CPU build on top of the stock llama-cpp.
      whisper-cpp = pkgs.whisper-cpp.override {
        cudaSupport = false;
        llama-cpp = pkgs.llama-cpp;
      };

      # TODO: remove once nixpkgs#576407 is in nixos-unstable (the filter is a
      # no-op after that). HandBrake's A15 pgssubdec patch no longer applies to
      # ffmpeg 8.1.3 (nixpkgs#576333), so drop it from HandBrake's ffmpeg.
      handbrake = pkgs.handbrake.overrideAttrs (old: {
        buildInputs = map (
          dep:
          if lib.hasPrefix "ffmpeg-full" (dep.name or "") then
            dep.overrideAttrs (ffmpegOld: {
              patches = builtins.filter (
                patch: !lib.hasInfix "A15-lavc-pgssubdec" (toString patch)
              ) ffmpegOld.patches;
            })
          else
            dep
        ) old.buildInputs;
      });

      # llama-swap from GitHub releases
      llama-swap =
        let
          version = "265";
        in
        pkgs.runCommand "llama-swap" { } ''
          mkdir -p $out/bin
          tar -xzf ${
            pkgs.fetchurl {
              url = "https://github.com/mostlygeek/llama-swap/releases/download/v${version}/llama-swap_${version}_linux_amd64.tar.gz";
              hash = "sha256-yx+alL4Fr6Ep08F4aPHdLKcQuRkzPHuGgjncMVddz6E=";
            }
          } -C $out/bin
          chmod +x $out/bin/llama-swap
        '';
    };
  };
}
