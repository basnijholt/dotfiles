# PC-specific package overrides (CUDA, custom packages)
# Note: allowUnfree is set in common/nixpkgs.nix
{ pkgs, ... }:

{
  nixpkgs.config = {
    cudaSupport = true;
    packageOverrides = pkgs: {
      ollama = (pkgs.ollama.override {
        # Only build for RTX 3090 (sm_86) instead of all 7 default architectures
        cudaArches = [ "sm_86" ];
      }).overrideAttrs (oldAttrs: rec {
        version = "0.15.4";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-5dkikrp7jVGnfFwiGkbsGsRnrsS0zcZzWQ7shOn3alw=";
        };
        vendorHash = "sha256-WdHAjCD20eLj0d9v1K6VYP8vJ+IZ8BEZ3CciYLLMtxc=";
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
            version = "7941";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-o8gSbm67lGk/4j55H0JN1LEfrod1MTaoKIUxcMTN0zo=";
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
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v189/llama-swap_189_linux_amd64.tar.gz";
            hash = "sha256-W1614G73DlGJlvgkQAtcI09zprRqDVfe0wjl9T8vGO4=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };
}
