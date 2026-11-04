# PC-specific package overrides (CUDA, custom packages)
# Note: allowUnfree is set in common/nixpkgs.nix
{ ... }:

{
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
                tag = "b11963";
                hash = "sha256-DUggBODOVSOydWopvdXt/K9ZiRrbWrl+mywpr1vjJwM=";
              };
            in
            rec {
              version = "0.40.14";
              src = pkgs.fetchFromGitHub {
                owner = "ollama";
                repo = "ollama";
                rev = "v${version}";
                hash = "sha256-IrTfIgwBqjdINyWqArWaa56k5ToeYW2RxTZiN/A12as=";
              };
              vendorHash = "sha256-1mzJrZUHH2ouP6I+LVojHbft7No5AumqKZVq0I/Ubsg=";
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
            version = "12098";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-NfQmRQZfxZwBMQUKyf/0drsCaZCrwCSuKGG9CBX0ZLY=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
            # test-llama-context-model requires the test-download-model
            # fixture, which needs network; CTest runs a required fixture even
            # when nixpkgs disables it. test-conversion-fp8 imports numpy,
            # which the build's Python lacks.
            disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
              "test-llama-context-model"
              "test-conversion-fp8"
            ];
            npmRoot = "tools/ui";
            npmDepsHash = "sha256-XLtEZsSFdk+2SyfXzBp8HQ2e27PQPpDCn1YjePU1/9w=";
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

      # llama-swap from GitHub releases
      llama-swap =
        let
          version = "269";
        in
        pkgs.runCommand "llama-swap" { } ''
          mkdir -p $out/bin
          tar -xzf ${
            pkgs.fetchurl {
              url = "https://github.com/mostlygeek/llama-swap/releases/download/v${version}/llama-swap_${version}_linux_amd64.tar.gz";
              hash = "sha256-kzpFxXhijL+kuFNTN8NamSZdRbjrkebc8AmpA3jw98w=";
            }
          } -C $out/bin
          chmod +x $out/bin/llama-swap
        '';
    };
  };
}
