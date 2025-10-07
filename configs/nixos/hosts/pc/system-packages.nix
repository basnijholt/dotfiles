{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    llama-cpp
    ollama
    cudatoolkit
    nvtopPackages.full
    rust-analyzer
    winetricks
  ];
}
