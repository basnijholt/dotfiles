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
      in
      {
      ollama = (pkgs.ollama.override {
        # Only build for RTX 3090 (sm_86) instead of all 7 default architectures
        cudaArches = [ "sm_86" ];
      }).overrideAttrs (oldAttrs: rec {
        version = "0.20.4";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-8TbZvxxaUdROpe3gnBx0XzX62tbQ9QeJP3Yp7XXJoTQ=";
        };
        vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
        preBuild = oldAttrs.preBuild + ''
          # Fix tree-sitter vendor: copy C sources that go mod vendor excludes
          if [ -d vendor/github.com/tree-sitter ]; then
            chmod -R u+w vendor/github.com/tree-sitter
            mkdir -p vendor/github.com/tree-sitter/go-tree-sitter vendor/github.com/tree-sitter/tree-sitter-cpp
            cp -r ${treeSitterGoSrc}/include vendor/github.com/tree-sitter/go-tree-sitter/
            cp -r ${treeSitterGoSrc}/src vendor/github.com/tree-sitter/go-tree-sitter/
            cp -r ${treeSitterCppSrc}/src vendor/github.com/tree-sitter/tree-sitter-cpp/
          fi
        '';
        postFixup = pkgs.lib.replaceStrings [
          ''mv "$out/bin/app" "$out/bin/.ollama-app"''
        ] [
          ''if [ -e "$out/bin/app" ]; then
             mv "$out/bin/app" "$out/bin/.ollama-app"
           fi''
        ] oldAttrs.postFixup;
      });

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
            version = "8708";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-Z3gU69z7xJMxckgRphT+n/5pCtnP4v36SWeHPuAY+kY=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
            npmDepsHash = "sha256-eeftjKt0FuS0Dybez+Iz9VTVMA4/oQVh+3VoIqvhVMw=";
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

            # Upstream nixpkgs removes a precompressed UI asset that no longer
            # exists in newer llama.cpp tags, so make that cleanup tolerant.
            postPatch = pkgs.lib.replaceStrings [
              "rm tools/server/public/index.html.gz"
            ] [
              "rm -f tools/server/public/index.html.gz"
            ] (oldAttrs.postPatch or "");
          });

      # llama-swap from GitHub releases
      llama-swap = pkgs.runCommand "llama-swap" { } ''
        mkdir -p $out/bin
        tar -xzf ${
          pkgs.fetchurl {
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v199/llama-swap_199_linux_amd64.tar.gz";
            hash = "sha256-KzGpX/g/zHQ0Mov5uWhx25liSI3h0zseByJ5uUZYilA=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };
}
