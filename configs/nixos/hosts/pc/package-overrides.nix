# PC-specific package overrides (CUDA, custom packages)
# Note: allowUnfree is set in common/nixpkgs.nix
{ pkgs, ... }:

{
  nixpkgs.config = {
    cudaSupport = true;
    packageOverrides = pkgs: {
      ollama = pkgs.ollama.overrideAttrs (oldAttrs: rec {
        version = "0.13.3";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-DsAgosnvkyGFPKSjjnE9dZ37CfqAIlvodpVjHLihX2A=";
        };
        vendorHash = "sha256-rKRRcwmon/3K2bN7iQaMap5yNYKMCZ7P0M1C2hv4IlQ=";
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
            version = "7667";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-1bgcQNFwLJS6t8NAN2AcGi5GE1HmufvkimxY1wnA9Rc=";
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

      # qdrant 1.16.3 - fixes gcc15/rocksdb build failure
      # PR: https://github.com/NixOS/nixpkgs/pull/465441
      qdrant =
        let
          version = "1.16.3";
          src = pkgs.fetchFromGitHub {
            owner = "qdrant";
            repo = "qdrant";
            tag = "v${version}";
            hash = "sha256-p2xQStTwbC6MoEsaM1JXlBHK2CqwIfD7x+WwciuY49s=";
          };
        in
        pkgs.qdrant.overrideAttrs (oldAttrs: {
          inherit version src;
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit src;
            hash = "sha256-DEOMoG13eDDEadScwQOD6jxuJBxaU2+fUNK/QLXLG8M=";
          };
        });

      # llama-swap from GitHub releases
      llama-swap = pkgs.runCommand "llama-swap" { } ''
        mkdir -p $out/bin
        tar -xzf ${
          pkgs.fetchurl {
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v182/llama-swap_182_linux_amd64.tar.gz";
            hash = "sha256-sHWd4odtHYCY6/NNOi0VJjtF3r6nMMIEVUXbraVoIkc=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };
}
