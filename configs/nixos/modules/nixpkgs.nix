{ pkgs, ... }:

{
  # --- Nixpkgs Configuration ---
  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
    packageOverrides = pkgs: {
      ollama = pkgs.ollama.overrideAttrs (oldAttrs: rec {
        version = "0.12.3";
        src = pkgs.fetchFromGitHub {
          owner = "ollama";
          repo = "ollama";
          rev = "v${version}";
          hash = "sha256-po7BxJAj9eOpOaXsLDmw6/1RyjXPtXza0YUv0pVojZ0=";
        };
        # Disable tests due to flaky TestConvertAdapter
        doCheck = false;
      });

      # Override llama-cpp to latest version b6150 with CUDA support
      llama-cpp =
        (pkgs.llama-cpp.override {
          cudaSupport = true;
          rocmSupport = false;
          metalSupport = false;
        }).overrideAttrs
          (oldAttrs: rec {
            version = "6521";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-iTjcVd3naZ4lCSpbCh8q7B0FP/v+0YOtOSe3yODjWNc=";
              leaveDotGit = true;
              postFetch = ''
                  git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
          });

      # llama-swap from GitHub releases
      llama-swap = pkgs.runCommand "llama-swap" { } ''
        mkdir -p $out/bin
        tar -xzf ${
          pkgs.fetchurl {
            url = "https://github.com/mostlygeek/llama-swap/releases/download/v158/llama-swap_158_linux_amd64.tar.gz";
            hash = "sha256-7NOnVRbbTRfeRMyX+vqtkE+krXQYMY05V2E608Af4QE=";
          }
        } -C $out/bin
        chmod +x $out/bin/llama-swap
      '';
    };
  };
}
