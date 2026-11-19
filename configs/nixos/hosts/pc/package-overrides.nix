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
              # Keep this llama.cpp tag aligned with the release's
              # LLAMA_CPP_VERSION; nixpkgs' postPatch checks that they match.
              llamaCppSrc = pkgs.fetchFromGitHub {
                owner = "ggml-org";
                repo = "llama.cpp";
                tag = "b12177";
                hash = "sha256-/bZRn+Zy4bqdJUWDX3a4+HClrsST60uXiNJT26mTgI0=";
              };
            in
            rec {
              version = "0.40.16";
              src = pkgs.fetchFromGitHub {
                owner = "ollama";
                repo = "ollama";
                rev = "v${version}";
                hash = "sha256-ita7MMcdRVBVNmOXnopJX31hnCaPHOx9079YGci5v18=";
              };
              vendorHash = "sha256-1mzJrZUHH2ouP6I+LVojHbft7No5AumqKZVq0I/Ubsg=";
              passthru = oldAttrs.passthru // {
                inherit llamaCppSrc;
                llamaCppVersion = llamaCppSrc.tag;
              };
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
            version = "12549";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-yg+0PxV7myyndL7wz4zlF0VaeUO1eZKBJ/Iy81Uw/T8=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
            # ggml-cuda includes nvml.h (loaded at runtime via dlopen), which
            # nixpkgs' llama-cpp does not provide yet.
            buildInputs = oldAttrs.buildInputs ++ [ pkgs.cudaPackages.cuda_nvml_dev ];
            npmRoot = "ui/apps/chat";
            npmDepsHash = "sha256-3kJJJGgPvtoRozjjvXJ97ljxzt0tshwi88UUd1D3VsI=";
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
          version = "274";
        in
        pkgs.runCommand "llama-swap" { } ''
          mkdir -p $out/bin
          tar -xzf ${
            pkgs.fetchurl {
              url = "https://github.com/mostlygeek/llama-swap/releases/download/v${version}/llama-swap_${version}_linux_amd64.tar.gz";
              hash = "sha256-iiaCF4OxAETcfL7giJLK7qdRfUiE7DhDIQKMma6yAIo=";
            }
          } -C $out/bin
          chmod +x $out/bin/llama-swap
        '';
    };
  };
}
