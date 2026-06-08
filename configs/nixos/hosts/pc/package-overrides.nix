# PC-specific package overrides (CUDA, custom packages)
# Note: allowUnfree is set in common/nixpkgs.nix
{ pkgs, ... }:

{
  nixpkgs.config = {
    cudaSupport = true;
    packageOverrides = pkgs:
      let
        # tree-sitter C sources needed by ollama 0.16.1+
        # go mod vendor doesn't copy C files from subdirectories without .go files
        treeSitterGoSrc = pkgs.fetchFromGitHub {
          owner = "tree-sitter";
          repo = "go-tree-sitter";
          rev = "adc13ffd8b2c0b01b878fda9f7c422ce0df5fad3"; # v0.25.0
          hash = "sha256-DVVhHQy0AEVyCig18JhlTVgttWaHJWRPdTSfwfFuKAk=";
        };
        treeSitterCppSrc = pkgs.fetchFromGitHub {
          owner = "tree-sitter";
          repo = "tree-sitter-cpp";
          rev = "v0.23.4";
          hash = "sha256-tP5Tu747V8QMCEBYwOEmMQUm8OjojpJdlRmjcJTbe2k=";
        };
        ollamaLlamaCppSrc = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b9509";
          hash = "sha256-bO1ucb/+vidj/EYzNCssotjte9NlVLdjC794jToNNeM=";
        };
      in
      {
      ollama = (pkgs.ollama.override {
        # Only build for RTX 3090 (sm_86) instead of all 7 default architectures
        cudaArches = [ "sm_86" ];
      }).overrideAttrs (oldAttrs: rec {
        version = "0.30.6";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-qO+Tsjg64QekGHNNiNy5YGSDoToGSnqiN5hN+0LCp4Q=";
        };
        vendorHash = "sha256-lZdGzGb9xRjTm1Rm7/wHjqM490gLznLEndmb4mNbCX0=";
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ pkgs.patchelf ];
        excludedPackages = (oldAttrs.excludedPackages or []) ++ [ "./integration" ];
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace cmd/launch/cline_test.go \
            --replace-fail '/bin/cat' '${pkgs.coreutils}/bin/cat' \
            --replace-fail '/bin/chmod' '${pkgs.coreutils}/bin/chmod'
          substituteInPlace cmd/launch/pi_test.go \
            --replace-fail '/bin/cat' '${pkgs.coreutils}/bin/cat' \
            --replace-fail '/bin/chmod' '${pkgs.coreutils}/bin/chmod'
          substituteInPlace cmd/launch/qwen_test.go \
            --replace-fail '/bin/mkdir' '${pkgs.coreutils}/bin/mkdir' \
            --replace-fail '/bin/cat' '${pkgs.coreutils}/bin/cat' \
            --replace-fail '/bin/chmod' '${pkgs.coreutils}/bin/chmod'
        '';
        preBuild =
          ''
            cp -r ${ollamaLlamaCppSrc} llama-cpp-source
            chmod -R u+w llama-cpp-source
            cmake -E chdir llama-cpp-source \
              cmake -DPATCH_DIR=$PWD/llama/compat -P $PWD/llama/compat/apply-patch.cmake
          ''
          +
          pkgs.lib.replaceStrings
            [ "cmake -B build \\" ]
            [ "cmake -B build \\\n  -DFETCHCONTENT_SOURCE_DIR_LLAMA_CPP=$PWD/llama-cpp-source \\" ]
            oldAttrs.preBuild
          + ''
          # Fix tree-sitter vendor: copy C sources that go mod vendor excludes
          if [ -d vendor/github.com/tree-sitter ]; then
            chmod -R u+w vendor/github.com/tree-sitter
            mkdir -p vendor/github.com/tree-sitter/go-tree-sitter vendor/github.com/tree-sitter/tree-sitter-cpp
            cp -r ${treeSitterGoSrc}/include vendor/github.com/tree-sitter/go-tree-sitter/
            cp -r ${treeSitterGoSrc}/src vendor/github.com/tree-sitter/go-tree-sitter/
            cp -r ${treeSitterCppSrc}/src vendor/github.com/tree-sitter/tree-sitter-cpp/
          fi
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
            version = "9566";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-31l+rGTrgNA2kciTxlyyQVjGMADfBRgAk2pd0jU9FMM=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
            npmRoot = "tools/ui";
            npmDepsHash = "sha256-pjdbI6NcZRlJVd62xhgbLhWrwFYwgsIwjORqvo1+VD8=";
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
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v223/llama-swap_223_linux_amd64.tar.gz";
            hash = "sha256-VkE35XdsH8YIl+So3g9zHtBvPqKO7AKhsxvbDyQITi4=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };
}
