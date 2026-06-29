# PC-specific package overrides (CUDA, custom packages)
# Note: allowUnfree is set in common/nixpkgs.nix
{ pkgs, ... }:

{
  nixpkgs.config = {
    cudaSupport = true;
    packageOverrides = pkgs:
      let
        # Ollama 0.30+ stages llama.cpp from the release's LLAMA_CPP_VERSION
        # during postPatch. Keep this pin aligned with the overridden Ollama
        # version; otherwise Ollama's compatibility patch can fail to apply.
        ollamaLlamaCppSrc = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b9781";
          hash = "sha256-AxMidqvx93b80GqDTgR34RCMdjr/UXDdeztxiXf6sEM=";
        };
      in
      {
      ollama = (pkgs.ollama.override {
        # Only build for RTX 3090 (sm_86) instead of all 7 default architectures
        cudaArches = [ "sm_86" ];
      }).overrideAttrs (oldAttrs: rec {
        version = "0.30.11";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-RQfRnzk5beJqkrK69f3BxK6QdkoEVTkbgEf1DkB6p1U=";
        };
        vendorHash = "sha256-lZdGzGb9xRjTm1Rm7/wHjqM490gLznLEndmb4mNbCX0=";
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ pkgs.patchelf ];
        excludedPackages = (oldAttrs.excludedPackages or []) ++ [ "./integration" ];
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
        postInstall = (oldAttrs.postInstall or "") + ''
          for lib in "$out"/lib/ollama/libggml-cpu-*.so; do
            [ -e "$lib" ] || continue

            rpath="$(patchelf --print-rpath "$lib")"
            newRpath=""
            IFS=':' read -r -a entries <<< "$rpath"
            for entry in "''${entries[@]}"; do
              case "$entry" in
                /build/*) continue ;;
              esac

              if [ -z "$newRpath" ]; then
                newRpath="$entry"
              else
                newRpath="$newRpath:$entry"
              fi
            done
            patchelf --set-rpath "$newRpath" "$lib"
          done
        '';
        postFixup = pkgs.lib.replaceStrings [
          ''mv "$out/bin/app" "$out/bin/.ollama-app"''
        ] [
          ''if [ -e "$out/bin/app" ]; then
             mv "$out/bin/app" "$out/bin/.ollama-app"
           fi''
        ] oldAttrs.postFixup;
      });

      # TODO: when ggml-org/llama.cpp#22673 lands upstream, revisit Gemma 4
      # MTP support. The current b9058 build has speculative decoding flags, but
      # not the --spec-type mtp / --mtp-head path needed for Gemma 4 assistants.
      # Override llama-cpp to latest version b6150 with CUDA support
      llama-cpp =
        (pkgs.llama-cpp.override {
          cudaSupport = true;
          rocmSupport = false;
          metalSupport = false;
          # Enable BLAS for optimized CPU layer performance (OpenBLAS)
          # This is crucial for models using split-mode or CPU offloading
          blasSupport = true;
        }).overrideAttrs
          (oldAttrs: rec {
            version = "9842";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-wtaHsVOyCNCITABe1TvDo/MiWpNlH2YqZewBDxERtt4=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
            npmRoot = "tools/ui";
            npmDepsHash = "sha256-X1DZgmhS/zHTqDT5zq0kywwntthcJ9vRXeqyO3zz6UU=";
            # Enable native CPU optimizations for massively better CPU performance
            # This enables AVX, AVX2, AVX-512, FMA, etc. for your specific CPU
            # NOTE: This is intentionally opposite of nixpkgs (which uses -DGGML_NATIVE=off
            # for reproducible builds). We sacrifice portability for faster CPU layers.
            cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
              "-DGGML_NATIVE=ON"
              "-DCMAKE_CUDA_ARCHITECTURES=86" # RTX 3090 - needed since sandbox has no GPU
            ];

            # Disable Nix's NIX_ENFORCE_NO_NATIVE which strips -march=native flags
            # See: https://github.com/NixOS/nixpkgs/issues/357736
            # See: https://github.com/NixOS/nixpkgs/pull/377484 (intentionally contradicts this)
            preConfigure = ''
              export NIX_ENFORCE_NO_NATIVE=0
              ${oldAttrs.preConfigure or ""}
            '';

          });

      # llama-swap from GitHub releases
      llama-swap = pkgs.runCommand "llama-swap" { } ''
        mkdir -p $out/bin
        tar -xzf ${
          pkgs.fetchurl {
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v232/llama-swap_232_linux_amd64.tar.gz";
            hash = "sha256-1pBfWe99yXNRrvowf+TNZs9LqgbXB2VX1O1+cjrxWI0=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };
}
