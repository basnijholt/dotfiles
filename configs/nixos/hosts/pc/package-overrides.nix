# PC-specific package overrides (CUDA, custom packages)
# Note: allowUnfree is set in common/nixpkgs.nix
{ pkgs, ... }:

{
  nixpkgs.config = {
    cudaSupport = true;
    packageOverrides =
      pkgs:
      let
        # Ollama 0.30+ stages llama.cpp from the release's LLAMA_CPP_VERSION
        # during postPatch. Keep this pin aligned with the overridden Ollama
        # version; otherwise Ollama's compatibility patch can fail to apply.
        ollamaLlamaCppSrc = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b10488";
          hash = "sha256-5noPIcSD9Ki1D3J7b6JofeXiPO1RdL/Q8z+E0ZCwceY=";
        };
      in
      {
        ollama =
          (pkgs.ollama.override {
            # Only build for RTX 3090 (sm_86) instead of all 7 default architectures
            cudaArches = [ "sm_86" ];
          }).overrideAttrs
            (oldAttrs: rec {
              version = "0.32.15";
              src = pkgs.fetchFromGitHub {
                owner = "ollama";
                repo = "ollama";
                rev = "v${version}";
                hash = "sha256-BpN3y1unf6Yd1RBura2S4O5jLSkImzi1Guo6GWbNZI8=";
              };
              vendorHash = "sha256-HMwoaFBMbpoy8f0I+O+i7kIa9BslLu3FcVWeaIOkpvs=";
              # This package only contains integration-tagged tests, so the
              # generic Go test sweep otherwise reports "build constraints
              # exclude all Go files".
              excludedPackages = (oldAttrs.excludedPackages or [ ]) ++ [ "./integration" ];
              postPatch = ''
                substituteInPlace version/version.go \
                  --replace-fail 0.0.0 '${version}'

                rm cmd/launch/*_test.go
                rm -r app

                cp -r ${ollamaLlamaCppSrc} $TMPDIR/llama-cpp-src
                chmod -R +w $TMPDIR/llama-cpp-src
                (
                  cd $TMPDIR/llama-cpp-src
                  cmake -DPATCH_DIR=$NIX_BUILD_TOP/source/llama/compat \
                    -P $NIX_BUILD_TOP/source/llama/compat/apply-patch.cmake
                )
              '';
            });

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
              version = "10618";
              src = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b${version}";
                hash = "sha256-ODJn/t+hAVMn5j0J2/1GOo3i2DE+YZvxT7MGLvkQKzM=";
                leaveDotGit = true;
                postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                  find "$out" -name .git -print0 | xargs -0 rm -rf
                '';
              };
              npmRoot = "tools/ui";
              npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
              # Target this host explicitly: Zen 2 CPU and RTX 3090 GPU. Using
              # znver2 instead of GGML_NATIVE avoids llama.cpp overriding the
              # explicit CUDA target with a sandbox-time GPU probe.
              cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
                "-DCMAKE_C_FLAGS=-march=znver2"
                "-DCMAKE_CXX_FLAGS=-march=znver2"
                "-DCMAKE_CUDA_ARCHITECTURES=86" # RTX 3090 - needed since sandbox has no GPU
              ];
            });

        # llama-swap from GitHub releases
        llama-swap = pkgs.runCommand "llama-swap" { } ''
          mkdir -p $out/bin
          tar -xzf ${
            pkgs.fetchurl {
              url = "https://github.com/mostlygeek/llama-swap/releases/download/v251/llama-swap_251_linux_amd64.tar.gz";
              hash = "sha256-hb1/Ix9Xd/9ri3h6eU+CVni40ELNRIQERRaljs3HYis=";
            }
          } -C $out/bin
          chmod +x $out/bin/llama-swap
        '';
      };
  };
}
