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
        version = "0.16.1";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-LdB/p3ZO+WCoU7xQz76suJ6Vc1TFAMGcLvMBib5w5fU=";
        };
        vendorHash = "sha256-OQOx0G4kxToe8soef4vZDhp1RtTnLkiT2tQBXgB3T5E=";
        preBuild = oldAttrs.preBuild + ''
          # Fix tree-sitter vendor: copy C sources that go mod vendor excludes
          chmod -R u+w vendor/github.com/tree-sitter
          cp -r ${treeSitterGoSrc}/include vendor/github.com/tree-sitter/go-tree-sitter/
          cp -r ${treeSitterGoSrc}/src vendor/github.com/tree-sitter/go-tree-sitter/
          cp -r ${treeSitterCppSrc}/src vendor/github.com/tree-sitter/tree-sitter-cpp/
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
            version = "8027";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-AEPdDOseqgBCNTzyjkzsJWhCAOX5oA493D6Qz/DOENk=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
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
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v190/llama-swap_190_linux_amd64.tar.gz";
            hash = "sha256-WAfmJ4YiVH/UYq++l2Ut6oLqkd270HgG7eV+6FG/0Oc=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };
}
